require "test_helper"

class ChatResponseJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper
  include QueryCountHelper

  test "enqueues chat titling after the response is persisted" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    stub_openai_chat(content: "Sure, here is how.")

    assert_enqueued_with(job: GenerateChatTitleJob, args: [ chat ]) do
      chat.messages.create!(role: :user, content: "How do I deploy Rails with Kamal?")
      ChatResponseJob.perform_now(chat.id)
    end
  end

  test "broadcasts each non-empty chunk that arrives a stream interval after the last one" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: :user, content: "How do I deploy Rails with Kamal?")
    stub_openai_chat_stream(chunks: [ "", "Sure", ", here", " is how." ])
    clear_messages("chat_#{chat.id}")

    respond_with_clock(chat, step: ChatResponseJob::STREAM_INTERVAL * 2)

    assert_equal [ "Sure", ", here", " is how." ], streamed_chunks(chat)
    assert_equal "Sure, here is how.", chat.messages.order(:created_at).last.content
  end

  test "coalesces chunks that arrive faster than the stream interval into one broadcast" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: :user, content: "Tell me a story")
    chunks = Array.new(500) { |index| " word#{index}" }
    stub_openai_chat_stream(chunks: chunks)
    clear_messages("chat_#{chat.id}")

    respond_with_clock(chat, step: ChatResponseJob::STREAM_INTERVAL / 4)

    reply = chat.messages.order(:created_at).last
    assert_equal chunks.join, reply.content
    assert_operator streamed_chunks(chat).size, :<=, 126
    assert reply.content.start_with?(streamed_chunks(chat).join)
    assert(broadcasts("chat_#{chat.id}").last.include?(ERB::Util.html_escape(chunks.join)))
  end

  test "a normal chat has no support instructions or tool attached" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    stub_openai_chat(content: "Sure, here is how.")

    chat.messages.create!(role: :user, content: "How do I deploy with Kamal?")
      ChatResponseJob.perform_now(chat.id)

    assert_nil chat.messages.find_by(role: "system")
  end

  test "a support chat's system instructions include the binding rule and the support context" do
    chat = users(:one).chats.create!(support: true)
    stub_openai_chat(content: "Sure, tell me more about what happened.")

    chat.messages.create!(role: :user, content: "The chat page is slow for me")
      ChatResponseJob.perform_now(chat.id)

    assert_requested :post, "https://api.openai.com/v1/chat/completions" do |request|
      instructions_message = JSON.parse(request.body)["messages"].find { |message| message["role"] != "user" }
      instructions_message &&
        instructions_message["content"].include?(SupportContext::BINDING_RULE) &&
        instructions_message["content"].include?(SupportContext.content)
    end
  end

  test "a support chat with a pre-existing persisted system message does not duplicate instructions" do
    chat = users(:one).chats.create!(support: true)
    chat.messages.create!(role: "system", content: "Stale instructions from before this refactor")
    stub_openai_chat(content: "Sure, tell me more about what happened.")

    chat.messages.create!(role: :user, content: "The chat page is slow for me")
      ChatResponseJob.perform_now(chat.id)

    assert_requested :post, "https://api.openai.com/v1/chat/completions" do |request|
      request.body.scan(SupportContext::BINDING_RULE).count == 1
    end
  end

  test "does not enqueue chat titling for a support chat" do
    chat = users(:one).chats.create!(support: true)
    stub_openai_chat(content: "Sure, tell me more about what happened.")

    assert_no_enqueued_jobs(only: GenerateChatTitleJob) do
      chat.messages.create!(role: :user, content: "The chat page is slow for me")
      ChatResponseJob.perform_now(chat.id)
    end
  end

  test "shows a human-friendly failure to the person when the provider fails" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: :user, content: "How do I deploy with Kamal?")
    stub_openai_chat_error(status: 500)

    clear_messages("chat_#{chat.id}")

    assert_raises(RubyLLM::Error) { ChatResponseJob.perform_now(chat.id) }

    failure_broadcasts = broadcasts("chat_#{chat.id}").map { |raw| JSON.parse(raw) }.select { |broadcasted| broadcasted.include?(I18n.t("messages.failure.body")) }

    assert_equal 1, failure_broadcasts.size
    failure_broadcast = failure_broadcasts.first
    assert_match(/action="append"/, failure_broadcast)
    assert_match(/target="chat_#{chat.id}_messages"/, failure_broadcast)
    assert_match(/id="chat_#{chat.id}_failure"/, failure_broadcast)
    assert_match(/role="alert"/, failure_broadcast)
    assert_no_match "500", failure_broadcast
    assert_no_match "Internal server error", failure_broadcast

    assert_nil chat.messages.reload.find_by(role: :assistant)
  end

  test "shows no failure when the reply succeeds" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    chat.messages.create!(role: :user, content: "How do I deploy with Kamal?")
    stub_openai_chat_stream(chunks: [ "Sure, here is how." ])

    clear_messages("chat_#{chat.id}")

    ChatResponseJob.perform_now(chat.id)

    assert_empty broadcasts("chat_#{chat.id}").select { |raw| raw.include?(I18n.t("messages.failure.body")) }
  end

  test "a support chat's tool call files a refined feedback ticket for the user" do
    chat = users(:one).chats.create!(support: true)
    stub_openai_chat_stream_with_tool_call(
      tool_name: "create_support_ticket",
      arguments: { title: "Chat page is slow", summary: "Pages take a long time to load for this person." },
      chunks: [ "Thanks, I've let the team know." ]
    )

    assert_difference("users(:one).feedbacks.count", 1) do
      chat.messages.create!(role: :user, content: "The chat page loads slowly for me")
      ChatResponseJob.perform_now(chat.id)
    end

    feedback = users(:one).feedbacks.last
    assert_includes feedback.message, "Chat page is slow"
    assert_includes feedback.message, "Pages take a long time to load for this person."
  end

  test "discards the answer for a chat deleted before it ran" do
    chat = users(:one).chats.create!(model: "gpt-4o-mini")
    ChatResponseJob.perform_later(chat.id)
    chat.destroy!

    assert_nothing_raised { perform_enqueued_jobs(only: ChatResponseJob) }
  end

  test "answers one turn of a chat at a time" do
    assert_equal 1, ChatResponseJob.concurrency_limit
    assert_equal ChatResponseJob.new(42).concurrency_key, ChatResponseJob.new(42).concurrency_key
    assert_not_equal ChatResponseJob.new(42).concurrency_key, ChatResponseJob.new(43).concurrency_key
  end

  test "the queries to answer do not grow with the history of a chat" do
    assert_equal queries_to_answer(history: 4), queries_to_answer(history: 8)
  end

  test "the queries to answer do not grow with the history of a support chat" do
    assert_equal queries_to_answer(history: 4, support: true), queries_to_answer(history: 8, support: true)
  end

  private

  def respond_with_clock(chat, step:)
    ticks = 0.0
    job = ChatResponseJob.new(chat.id)
    job.define_singleton_method(:now) { ticks += step }
    job.perform_now
  end

  def streamed_chunks(chat)
    broadcasts("chat_#{chat.id}").map { |raw| JSON.parse(raw) }
      .grep(/target="message_\d+_content"/)
      .map { |stream| stream[%r{<template>(.*)</template>}m, 1] }
  end

  def queries_to_answer(history:, support: false)
    chat = users(:one).chats.create!(model: "gpt-4o-mini", support: support)
    now = Time.current
    Message.insert_all(Array.new(history) do |index|
      { chat_id: chat.id, role: index.even? ? "user" : "assistant", model_id: index.even? ? nil : chat.model.id,
        content: "Seeded", created_at: now - (history - index).minutes, updated_at: now }
    end)
    chat.messages.create!(role: :user, content: "And now?")
    stub_openai_chat(content: "Sure.")

    queries_to { ChatResponseJob.perform_now(chat.id) }
  end
end

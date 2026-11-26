module OpenaiStubs
  def stub_openai_chat(content:)
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        id: "chatcmpl-test", object: "chat.completion", created: 0, model: "gpt-5.4-nano",
        choices: [ { index: 0, message: { role: "assistant", content: content }, finish_reason: "stop" } ],
        usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 }
      }.to_json
    )
  end

  def stub_openai_chat_stream(chunks:)
    body = chunks.map { |content| server_sent_event(content: content) }.join
    body << server_sent_event(content: nil, finish_reason: "stop")
    body << "data: [DONE]\n\n"

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: /"stream":true/)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "text/event-stream" },
        body: body
      )
  end

  def stub_openai_chat_stream_with_tool_call(tool_name:, arguments:, chunks:)
    tool_call_stream = tool_call_stream_event(name: tool_name, arguments: arguments)
    tool_call_stream << server_sent_event(content: nil, finish_reason: "tool_calls")
    tool_call_stream << "data: [DONE]\n\n"

    final_stream = chunks.map { |content| server_sent_event(content: content) }.join
    final_stream << server_sent_event(content: nil, finish_reason: "stop")
    final_stream << "data: [DONE]\n\n"

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: /"stream":true/)
      .to_return(
        { status: 200, headers: { "Content-Type" => "text/event-stream" }, body: tool_call_stream },
        { status: 200, headers: { "Content-Type" => "text/event-stream" }, body: final_stream }
      )
  end

  def stub_openai_chat_stream_with_endless_tool_calls(tool_name:, arguments:)
    tool_call_stream = tool_call_stream_event(name: tool_name, arguments: arguments)
    tool_call_stream << server_sent_event(content: nil, finish_reason: "tool_calls")
    tool_call_stream << "data: [DONE]\n\n"

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: /"stream":true/)
      .to_return(status: 200, headers: { "Content-Type" => "text/event-stream" }, body: tool_call_stream)
  end

  def stub_openai_chat_error(status: 500)
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: status,
      headers: { "Content-Type" => "application/json" },
      body: { error: { message: "Internal server error" } }.to_json
    )
  end

  def stub_openai_embedding(vector:)
    stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        object: "list", model: "text-embedding-3-small",
        data: [ { object: "embedding", index: 0, embedding: vector } ],
        usage: { prompt_tokens: 1, total_tokens: 1 }
      }.to_json
    )
  end

  private

  def tool_call_stream_event(name:, arguments:)
    chunk = {
      id: "chatcmpl-test", object: "chat.completion.chunk", created: 0, model: "gpt-5.4-nano",
      choices: [ {
        index: 0,
        delta: {
          tool_calls: [ {
            index: 0, id: "call_1", type: "function",
            function: { name: name, arguments: arguments.to_json }
          } ]
        },
        finish_reason: nil
      } ]
    }
    "data: #{chunk.to_json}\n\n"
  end

  def server_sent_event(content:, finish_reason: nil)
    delta = content.nil? ? {} : { content: content }
    chunk = {
      id: "chatcmpl-test", object: "chat.completion.chunk", created: 0, model: "gpt-5.4-nano",
      choices: [ { index: 0, delta: delta, finish_reason: finish_reason } ]
    }
    "data: #{chunk.to_json}\n\n"
  end
end

class ActiveSupport::TestCase
  include OpenaiStubs
end

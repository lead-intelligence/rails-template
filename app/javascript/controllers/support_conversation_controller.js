import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "pending"]

  connect() {
    this.observer = new MutationObserver(() => this.settle())
    this.observer.observe(this.messagesTarget, { childList: true, subtree: true, characterData: true })
    this.scrollToEnd()
  }

  disconnect() {
    this.observer.disconnect()
  }

  sending() {
    this.replyBeforeSending = this.lastReply()
  }

  awaiting() {
    if (!this.repliedSinceSending()) this.pendingTarget.classList.remove("hidden")
    this.scrollToEnd()
  }

  settle() {
    if (this.answered()) this.pendingTarget.classList.add("hidden")
    this.scrollToEnd()
  }

  repliedSinceSending() {
    return this.answered() && this.lastReply() !== this.replyBeforeSending
  }

  answered() {
    const last = this.lastReply()
    return Boolean(last && last.textContent.trim().length > 0)
  }

  lastReply() {
    const bubbles = this.messagesTarget.querySelectorAll(".chat-start .chat-bubble")
    return bubbles[bubbles.length - 1]
  }

  scrollToEnd() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}

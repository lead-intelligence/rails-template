import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

export default class extends Controller {
  remember(event) {
    document.cookie = `theme=${event.target.value}; path=/; max-age=${ONE_YEAR}; samesite=lax`
  }
}

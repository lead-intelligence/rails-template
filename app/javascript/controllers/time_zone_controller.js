import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

export default class extends Controller {
  connect() {
    const zone = encodeURIComponent(Intl.DateTimeFormat().resolvedOptions().timeZone)

    if (!document.cookie.split("; ").includes(`time_zone=${zone}`)) {
      document.cookie = `time_zone=${zone}; path=/; max-age=${ONE_YEAR}; samesite=lax`
    }
  }
}

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "lexxy"

import confirmDialog from "confirm_dialog"
import discardStaleStreamUpdates from "discard_stale_stream_updates"
import reportJavascriptErrors from "error_reporting"

Turbo.config.forms.confirm = confirmDialog
document.addEventListener("turbo:load", () => {
  controllersLoaded().then(() => document.body.setAttribute("data-turbo-ready", ""))
})
discardStaleStreamUpdates()
reportJavascriptErrors()

function controllersLoaded() {
  const importmap = JSON.parse(document.querySelector("script[type=importmap]").text)
  const paths = Object.keys(importmap.imports).filter(path => path.match(/^controllers\/.*_controller$/))
  return Promise.allSettled(paths.map(path => import(path)))
}
import "reactionview"

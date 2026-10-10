# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "lexxy", to: "lexxy.js", preload: false
pin "confirm_dialog"
pin "discard_stale_stream_updates"
pin "error_reporting"
pin "load_rich_text_editor"

# ActiveStorage for file uploads
pin "@rails/activestorage", to: "activestorage.esm.js", preload: false

pin "railspress", to: "railspress/index.js", preload: false
pin_all_from Railspress::Engine.root.join("app/javascript/railspress/controllers"), under: "railspress/controllers", to: "railspress/controllers", preload: false

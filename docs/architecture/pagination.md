# Pagination

Pagy paginates every list that grows with use. It is a direct dependency in the `Gemfile`, although madmin already depends on it, so its major version is the app's choice and not a side effect of the admin panel.

`config/initializers/pagy.rb` calls `Pagy.translate_with_the_slower_i18n_gem!`. Pagy's own translator keeps its locale in a thread variable that defaults to English and never sees `I18n.with_locale`, so without that line every navigation renders in English while the page around it is Spanish. The switch makes Pagy look its keys up through the Rails I18n gem and appends the gem's own `es` and `en` dictionaries to the load path; the app's locale files carry no `pagy` keys. `test/integration/pagy_configuration_test.rb` proves both locales.

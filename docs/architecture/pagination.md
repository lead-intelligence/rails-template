# Pagination

Pagy paginates every list that grows with use. It is a direct dependency in the `Gemfile`, although madmin already depends on it, so its major version is the app's choice and not a side effect of the admin panel.

`config/initializers/pagy.rb` calls `Pagy.translate_with_the_slower_i18n_gem!`. Pagy's own translator keeps its locale in a thread variable that defaults to English and never sees `I18n.with_locale`, so without that line every navigation renders in English while the page around it is Spanish. The switch makes Pagy look its keys up through the Rails I18n gem and appends the gem's own `es` and `en` dictionaries to the load path; the app's locale files carry no `pagy` keys. `test/integration/pagy_configuration_test.rb` proves both locales.

Each controller declares its page size as a `PER_PAGE` constant and passes it to `pagy(…, limit:)`; `include Pagy::Method` in `ApplicationController` gives every controller the `pagy` method. The views render `app/views/shared/_pagination.html.erb`, which prints Pagy's own `series_nav` only when there is more than one page. That helper writes the accessible markup — an `aria-label` on the `nav`, `aria-current` on the current page, `aria-disabled` and no `href` on a dead previous or next, `rel` on the live ones — and links are plain GET anchors that Turbo Drive follows. Its output is a plain string, so the partial prints it with `<%==`.

The nav is styled with DaisyUI and no markup of the app's own: `app/assets/tailwind/application.css` applies `join`, `join-item btn btn-sm`, `btn-primary` and `btn-disabled` to the `.pagy.series-nav` selectors. Pagy's helper accepts no class for the current, disabled or gap items, so a selector is the only seam that reaches all of them; a hand-written nav would have to restate the accessibility markup and would drift from it.

A page past the last one is not an error: Pagy serves it as an empty page, so the list renders its empty state and no nav.

# Money

money-rails is installed and configured in `config/initializers/money.rb`, with USD as the default currency. No model is monetized: an app opts in per model.

A monetized column is `t.monetize :price` in a migration, which creates `price_cents` and `price_currency`, plus `monetize :price_cents` on the model. Storing integer cents rather than a decimal keeps sums exact.

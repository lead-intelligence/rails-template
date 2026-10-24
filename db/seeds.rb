# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

RubyLLM.config.model_registry_store.write(RubyLLM.models.load_from_json)

if Rails.env.development?
  User.find_or_create_by!(email_address: "dev@example.com") do |user|
    user.name = "Dev User"
    user.password = "password"
    user.confirmed_at = Time.current
  end
  ENV["SEED_OWNER"] ||= "dev@example.com"
end

# The data to try each feature with: one file per feature in db/seeds/, for the user SEED_OWNER
# names. Staging names its owner and runs this on every build, so each file finds or creates its
# records. Production names nobody, and gets none.
if ENV["SEED_OWNER"].present?
  Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load file }
end

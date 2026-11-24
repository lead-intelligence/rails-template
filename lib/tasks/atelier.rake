# What Atelier (Peronix) runs in this app. Each app keeps its own, so Atelier
# never needs to know how the app's models look.
namespace :atelier do
  # The owner's account, made once: on staging for each request, and in
  # production on the first ship. EMAIL and PASSWORD come in the environment,
  # never in the arguments, which ps shows. It exits 3 when the account
  # already exists, and changes nothing then.
  desc "Make the owner's account for EMAIL with PASSWORD (Atelier runs it)"
  task owner: :environment do
    user = User.find_or_initialize_by(email_address: ENV.fetch("EMAIL"))
    exit 3 unless user.new_record?
    user.update!(name: "Owner", password: ENV.fetch("PASSWORD"), confirmed_at: Time.current)
  end

  # Who a tester can sign in as on staging: one "email<TAB>label" line per
  # account, the owner first (the oldest account outside the demo domain),
  # then the demo accounts the seeds make with User.demo_account!.
  desc "List the accounts a tester can sign in as, owner first (Atelier runs it)"
  task people: :environment do
    User.atelier_people.each { |user| puts "#{user.email_address}\t#{user.atelier_label}" }
  end

  # Gives a person access with no email: it finds or makes the account for
  # EMAIL, confirmed, and prints one line, the app's own link to choose a
  # password (PasswordsController). The link lasts as long as the app's reset
  # links do, and only until the password changes. NAME, ROLE and ADMIN
  # ("true" or "false") set those columns of the account; a blank one keeps
  # it. An app whose users have no such column refuses it, and its User model
  # checks the rest: an unknown role, what a role needs.
  desc "Give EMAIL access and print a link to choose its password (Atelier runs it)"
  task access: :environment do
    user = User.find_or_initialize_by(email_address: ENV.fetch("EMAIL"))
    user.password = SecureRandom.base58(24) if user.new_record?
    user.confirmed_at ||= Time.current
    { "name" => ENV["NAME"], "role" => ENV["ROLE"], "admin" => ENV["ADMIN"] }.compact_blank.each do |column, value|
      abort "this app's users have no #{column}" unless User.column_names.include?(column)
      user.public_send("#{column}=", value)
    end
    user.save!
    puts Rails.application.routes.url_helpers.edit_password_url(user.password_reset_token, **ActionMailer::Base.default_url_options)
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    abort e.message
  end
end

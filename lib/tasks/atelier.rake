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
end

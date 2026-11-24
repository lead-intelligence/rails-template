class User < ApplicationRecord
  DAILY_MESSAGE_LIMIT = 100
  NAME_MAX_LENGTH = 100
  EMAIL_CONFIRMATION_EXPIRES_IN = 1.day
  UNCONFIRMED_RETENTION = 7.days
  DELETION_SWEEP_DELAY = 1.hour
  DEMO_DOMAIN = "demo.test"

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :push_devices, as: :owner, class_name: "ApplicationPushDevice", dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :messages, through: :chats
  has_many :documents, dependent: :destroy
  has_many :ruby_llm_usages, as: :owner, class_name: "RubyLLM::ActiveRecord::Usage", dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  has_many :ahoy_visits, dependent: :destroy, class_name: "Ahoy::Visit"
  has_many :ahoy_events, dependent: :destroy, class_name: "Ahoy::Event"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :unconfirmed_email, with: ->(e) { e.strip.downcase.presence }

  generates_token_for :email_confirmation, expires_in: EMAIL_CONFIRMATION_EXPIRES_IN do
    email_address
  end

  generates_token_for :email_change, expires_in: EMAIL_CONFIRMATION_EXPIRES_IN do
    unconfirmed_email
  end

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 48, 48 ]
    attachable.variant :medium, resize_to_fill: [ 200, 200 ]
  end

  has_one_attached :data_export

  scope :able_to_sign_in, -> { where.not(confirmed_at: nil).where(deletion_requested_at: nil) }
  scope :demo, -> { where(arel_table[:email_address].matches("%@#{DEMO_DOMAIN}")) }
  scope :not_demo, -> { where(arel_table[:email_address].does_not_match("%@#{DEMO_DOMAIN}")) }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :unconfirmed_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :password_challenge, presence: true, on: :profile, if: :changing_credentials?
  validate :unconfirmed_email_not_taken, on: :profile, if: :unconfirmed_email?
  validates :avatar, **Photo::VALIDATION

  def self.demo_account!(role, name:)
    find_or_create_by!(email_address: "#{role}@#{DEMO_DOMAIN}") do |user|
      user.name = name
      user.password = SecureRandom.base58(24)
      user.confirmed_at = Time.current
    end
  end

  def self.atelier_people
    people = able_to_sign_in.order(:id)
    [ people.not_demo.first, *people.demo ].compact
  end

  def self.from_atelier_token(token, key:)
    payload, signature = token.to_s.split(".", 2)
    return unless ActiveSupport::SecurityUtils.secure_compare(OpenSSL::HMAC.hexdigest("SHA256", key, payload.to_s), signature.to_s)
    return unless JSON.parse(Base64.urlsafe_decode64(payload), symbolize_names: true) in { email: String => email, exp: Integer => exp }

    able_to_sign_in.find_by(email_address: email.strip.downcase) if exp >= Time.current.to_i
  rescue ArgumentError, JSON::ParserError
    nil
  end

  def atelier_label
    if email_address.end_with?("@#{DEMO_DOMAIN}")
      I18n.t("atelier.people.#{email_address.delete_suffix("@#{DEMO_DOMAIN}")}", default: name)
    else
      I18n.t("atelier.people.owner")
    end
  end

  def initials
    name.to_s.split.first(2).filter_map { |part| part[0] }.join.upcase
  end

  def messages_remaining_today
    [ DAILY_MESSAGE_LIMIT - messages_sent_today, 0 ].max
  end

  def messages_sent_today
    messages_sent_on == Date.current ? messages_sent_count : 0
  end

  def count_sent_messages(count = 1)
    with_lock { update_columns(messages_sent_on: Date.current, messages_sent_count: messages_sent_today + count) }
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end

  def confirm_email_change
    update(email_address: unconfirmed_email, unconfirmed_email: nil)
  end

  def self.purge_unconfirmed
    where(confirmed_at: nil, created_at: ...UNCONFIRMED_RETENTION.ago).find_each(&:destroy)
  end

  def self.finish_requested_deletions
    where(deletion_requested_at: ...DELETION_SWEEP_DELAY.ago).find_each(&:destroy)
  end

  def request_deletion!
    transaction do
      touch(:deletion_requested_at)
      sessions.delete_all
    end
    AccountDeletionJob.perform_later(self)
  end

  def deletion_requested?
    deletion_requested_at.present?
  end

  private

  def unconfirmed_email_not_taken
    errors.add(:unconfirmed_email, :taken) if User.where.not(id: id).exists?(email_address: unconfirmed_email)
  end

  def changing_credentials?
    password.present? || unconfirmed_email_changed?
  end
end

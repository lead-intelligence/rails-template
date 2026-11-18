module AtelierTokenHelper
  def atelier_token(email:, exp: 5.minutes.from_now.to_i, key: ENV.fetch("ATELIER_ENTER_KEY"))
    payload = Base64.urlsafe_encode64({ email:, exp: }.to_json, padding: false)
    "#{payload}.#{OpenSSL::HMAC.hexdigest("SHA256", key, payload)}"
  end

  def with_atelier_enter_key(key = "test-enter-key")
    before = ENV["ATELIER_ENTER_KEY"]
    ENV["ATELIER_ENTER_KEY"] = key
    yield
  ensure
    ENV["ATELIER_ENTER_KEY"] = before
  end
end

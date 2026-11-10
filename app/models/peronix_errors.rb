require "net/http"

class PeronixErrors
  Error = Class.new(StandardError)

  class << self
    def configured?
      url.present? && token.present?
    end

    def report(entry)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = entry.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
      raise Error, "Peronix answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response
    end

    private

    def url
      Rails.configuration.x.peronix.to_h[:errors_url] || ENV["PERONIX_ERRORS_URL"]
    end

    def token
      Rails.configuration.x.peronix.to_h[:errors_token] || ENV["PERONIX_ERRORS_TOKEN"]
    end
  end
end

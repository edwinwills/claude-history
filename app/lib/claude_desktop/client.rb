require "net/http"
require "json"
require "uri"

module ClaudeDesktop
  # Thin wrapper around the unofficial claude.ai internal endpoints.
  # Auth is a session cookie (the `sessionKey` cookie set by claude.ai on login).
  # These endpoints are not a public contract; treat breakage as expected.
  class Client
    BASE = "https://claude.ai".freeze
    # Cloudflare in front of claude.ai aggressively 403s non-browser User-Agents.
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36".freeze

    class Error < StandardError; end
    class AuthError < Error; end
    class RateLimited < Error; end
    class NetworkError < Error; end

    def initialize(session_key:, base: BASE, http: nil)
      raise ArgumentError, "session_key is required" if session_key.to_s.strip.empty?
      @session_key = session_key
      @base = base
      @http = http
    end

    def organizations
      get_json("/api/organizations")
    end

    def conversations(org_uuid)
      get_json("/api/organizations/#{org_uuid}/chat_conversations")
    end

    def conversation(org_uuid, conv_uuid)
      get_json("/api/organizations/#{org_uuid}/chat_conversations/#{conv_uuid}?tree=True&rendering_mode=messages")
    end

    private

    def get_json(path)
      if @http
        return @http.call(path)
      end

      uri = URI.join(@base, path)
      req = Net::HTTP::Get.new(uri)
      req["Cookie"] = format_cookie(@session_key)
      req["User-Agent"] = USER_AGENT
      req["Accept"] = "application/json"
      req["Accept-Language"] = "en-US,en;q=0.9"
      req["Referer"] = "https://claude.ai/"
      req["Origin"] = "https://claude.ai"
      req["Sec-Fetch-Dest"] = "empty"
      req["Sec-Fetch-Mode"] = "cors"
      req["Sec-Fetch-Site"] = "same-origin"

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        http.request(req)
      end

      case res.code.to_i
      when 200..299
        JSON.parse(res.body)
      when 401, 403
        raise AuthError, "claude.ai returned #{res.code}: session cookie rejected or expired"
      when 429
        raise RateLimited, "claude.ai returned 429: rate limited"
      else
        raise Error, "claude.ai returned #{res.code} for #{path}: #{res.body.to_s[0, 200]}"
      end
    rescue Socket::ResolutionError, Errno::ECONNREFUSED, Errno::ETIMEDOUT,
           Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise NetworkError, "couldn't reach claude.ai (#{e.class}: #{e.message})"
    end

    # Accept either a full Cookie header (name=value; name=value; …) or a bare
    # sessionKey value and produce a valid Cookie header. A full header is
    # required whenever claude.ai has a Cloudflare challenge in play, because
    # cf_clearance must also be present.
    def format_cookie(value)
      s = value.to_s.strip
      if s.include?("=")
        s
      else
        "sessionKey=#{s}"
      end
    end
  end
end

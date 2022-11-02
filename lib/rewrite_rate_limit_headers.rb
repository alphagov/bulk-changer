# Rewrites X-RateLimit headers so that the Faraday::Retry::Middleware can read them and
# automatically wait until the rate limit expires before retrying
class RewriteRateLimitHeaders < Faraday::Middleware
  def initialize(app)
    super(app)
    @app = app
  end

  def call(request_env)
    @app.call(request_env).on_complete do |response_env|
      headers = response_env[:response_headers]
      if headers.include?("X-RateLimit-Limit") && !headers.include?("RateLimit-Limit")
        headers["RateLimit-Limit"] = headers["X-RateLimit-Limit"]
      end
      if headers.include?("X-RateLimit-Remaining") && !headers.include?("RateLimit-Remaining")
        headers["RateLimit-Remaining"] = headers["X-RateLimit-Remaining"]
      end
      if headers.include?("X-RateLimit-Reset") && !headers.include?("RateLimit-Reset")
        # X-RateLimit-Reset is a timestamp (i.e. the number of seconds since epoch)
        # RateLimit-Reset is expected to be in RFC2822 format
        # (We add 5 extra seconds for safety, in case the client & server clocks are out of sync)
        headers["RateLimit-Reset"] = Time.at(headers["X-RateLimit-Reset"].to_i + 5).rfc2822
      end
    end
  end
end

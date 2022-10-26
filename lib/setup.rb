$LOAD_PATH.prepend "lib"

require "rubygems"
require "bundler/setup"
require "octokit"
require "rewrite_rate_limit_headers"

Octokit.auto_paginate = true
Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::Retry::Middleware, { exceptions: Octokit::TooManyRequests }
  builder.use Octokit::Middleware::FollowRedirects
  builder.use Octokit::Response::RaiseError
  builder.use Octokit::Response::FeedParser
  builder.use RewriteRateLimitHeaders
  builder.adapter Faraday.default_adapter
end

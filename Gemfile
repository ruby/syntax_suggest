# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in dead_end.gemspec
gemspec

gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "stackprof"
gem "standard"
gem "ruby-prof"

gem "benchmark-ips"

case ENV["PRISM_VERSION"]&.strip&.downcase
when "head"
  gem "prism", github: "ruby/prism"
when nil, ""
  gem "prism"
else
  gem "prism", ENV["PRISM_VERSION"]
end

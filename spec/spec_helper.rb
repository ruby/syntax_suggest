# frozen_string_literal: true

require "bundler/setup"

require 'tempfile'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def spec_dir
  Pathname(__dir__)
end

def lib_dir
  root_dir.join("lib")
end

def root_dir
  spec_dir.join("..")
end

def fixtures_dir
  spec_dir.join("fixtures")
end

def run!(cmd)
  out = `#{cmd} 2>&1`
  raise "Command: #{cmd} failed: #{out}" unless $?.success?
  out
end

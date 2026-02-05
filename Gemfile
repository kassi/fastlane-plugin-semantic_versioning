# frozen_string_literal: true

source("https://rubygems.org")

# Calculates the set of unique abbreviations for a given set of strings.
gem "abbrev", "~> 0.1.2"
# Provides a consistent environment for Ruby projects by tracking and installing exact gem versions.
gem "bundler"
# Provides a fake file system to test diverse file operations
gem "fakefs", "~> 2.5"
# Automation tool for mobile developers.
gem "fastlane", ">= 2.220.0"
# Provides fast development by watching and automatically running tests.
gem "guard", "~> 2.18"
# Guard helper for RSpec tests.
gem "guard-rspec", "~> 4.7"
# Provides an interactive debugging environment for Ruby.
gem "guard-rubocop", "~> 1.5"
# Interactive Ruby shell for experimentation and debugging.
gem "irb"
# Provides OpenStruct, a data structure similar to Hash that allows attribute-style access.
gem "ostruct", "~> 0.6.3"
# Provides an interactive debugging environment for Ruby.
gem "pry"
# A simple task automation tool.
gem "rake"
# Behavior-driven testing tool for Ruby.
gem "rspec"
# Use test files in tests.
gem "rspec-file_fixtures", "~> 0.1.9"
# Formatter for RSpec to generate JUnit compatible reports.
gem "rspec_junit_formatter"
# A Ruby static code analyzer and formatter.
gem "rubocop", "1.50.2"
# A collection of RuboCop cops for performance optimizations.
gem "rubocop-performance"
# A RuboCop extension focused on RSpec files.
gem "rubocop-rspec"
# SimpleCov is a code coverage analysis tool for Ruby.
gem "simplecov"
# Provide coverage information in LCOV style to be read by code editor
gem "simplecov-lcov"

gemspec

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)

# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

if RSpec.configuration.instance_variable_get(:@files_or_directories_to_run) == %w[spec]
  require "simplecov"
  require "simplecov-lcov"
  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.output_directory = "coverage"
    c.lcov_file_name = "lcov.info"
    c.report_with_single_file = true
  end
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                   SimpleCov::Formatter::HTMLFormatter,
                                                                   SimpleCov::Formatter::LcovFormatter
                                                                 ])
  # SimpleCov.minimum_coverage 95
  SimpleCov.start
end

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require "fastlane" # to import the Action super class
require "fastlane/plugin/semantic_versioning" # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)

RSpec.configure do |config|
  config.filter_run_when_matching(:focus)
end

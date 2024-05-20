#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

fixtures_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../../fixtures"))

valid_project = Xcodeproj::Project.new("#{fixtures_path}/valid.xcodeproj")
valid_project.new_target(:application, "Valid", :ios)
valid_project.new_group("Valid", "Valid")
debug = valid_project.add_build_configuration("Debug", :debug)
debug.build_settings = {
  "MARKETING_VERSION" => "1.0",
  "GENERATE_INFOPLIST_FILE" => "YES"
}
release = valid_project.add_build_configuration("Release", :release)
release.build_settings = {
  "MARKETING_VERSION" => "1.0",
  "GENERATE_INFOPLIST_FILE" => "YES"
}
valid_project.save

# frozen_string_literal: true

require "fastlane/plugin/semantic_versioning/version"

module Fastlane
  # Provides actions for dealing with semantic versions and conventional commits
  module SemanticVersioning
    # Return all .rb files inside the "actions" and "helper" directory
    def self.all_classes
      Dir[File.expand_path("**/{actions,helper}/*.rb", File.dirname(__FILE__))]
    end
  end
end

# By default we want to import all available actions and helpers
# A plugin can contain any number of actions and plugins
Fastlane::SemanticVersioning.all_classes.each do |current|
  require current
end

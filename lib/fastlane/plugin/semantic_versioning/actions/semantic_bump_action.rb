# frozen_string_literal: true

require "fastlane/action"
require_relative "../helper/semantic_versioning_helper"

module Fastlane
  module Actions
    # Action to bumps the version according to semantic versioning and writes a changelog.
    class SemanticBumpAction < Action
      def self.run(params)
        unless Actions.lane_context.key?(SharedValues::SEMVER_BUMPABLE) && Actions.lane_context.key?(SharedValues::SEMVER_VERSIONING_SYSTEM)
          UI.user_error!("No semver information found. Please run get_versioning_info beforehand.")
        end

        Helper::SemanticVersioningHelper.verify_versioning_system(Actions.lane_context[SharedValues::SEMVER_VERSIONING_SYSTEM])

        unless Actions.lane_context[SharedValues::SEMVER_BUMPABLE]
          UI.message("No version bump detected.")
          return false
        end

        system = Actions.lane_context[SharedValues::SEMVER_VERSIONING_SYSTEM]
        version_number = Actions.lane_context[SharedValues::SEMVER_NEW_VERSION]
        next_changelog = Actions.lane_context[SharedValues::SEMVER_NEW_CHANGELOG]

        Helper::SemanticVersioningHelper.set_version_number(version_number: version_number, system: system)

        if params[:changelog_file]
          Helper::SemanticVersioningHelper.write_changelog(
            path: params[:changelog_file],
            changelog: next_changelog
          )
        end

        Fastlane::Actions::CommitVersionBumpAction.run(
          message: Helper::SemanticVersioningHelper.bump_message(params[:bump_message]),
          force: true,
          include: [params[:changelog_file]].compact
        )

        true
      end

      # :nocov:
      def self.description
        "Bumps the version according to semantic versioning and writes a changelog."
      end

      def self.authors
        ["kassi"]
      end

      def self.output
        # Define the shared values you are going to provide
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns true when the bump was successful, false otherwise."
      end

      def self.details
        # Optional:
        "Reads commits from last version and determines next version and changelog."
      end
      # :nocov:

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :bump_message,
                                       env_name: "SEMANTIC_VERSIONING_BUMP_MESSAGE",
                                       description: "The commit mesage to use for the bump commit",
                                       optional: true,
                                       default_value: "version $current_version → $new_version",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_file,
                                       env_name: "SEMANTIC_VERSIONING_CHANGELOG_FILE",
                                       description: "Filename for the changelog",
                                       optional: true,
                                       default_value: "CHANGELOG.md",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :versioning_system,
                                       env_name: "SEMANTIC_VERSIONING_VERSIONING_SYSTEM",
                                       description: "Type of versioning to use. Can be 'manual' or 'apple-generic'." \
                                                    "For 'apple-generic', the project has to be prepared with prepare_versioning." \
                                                    "Defaults to 'manual'",
                                       optional: true,
                                       default_value: "manual",
                                       is_string: true,
                                       verify_block: ->(value) { Helper::SemanticVersioningHelper.verify_versioning_system(value) })
        ]
      end

      # :nocov:
      def self.is_supported?(_platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
      # :nocov:
    end
  end
end

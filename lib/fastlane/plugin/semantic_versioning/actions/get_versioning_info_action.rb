# frozen_string_literal: true

require "fastlane/action"
require "fastlane_core/configuration/config_item"
require_relative "../helper/semantic_versioning_helper"

module Fastlane
  module Actions
    module SharedValues
      SEMVER_CURRENT_VERSION = :SEMVER_CURRENT_VERSION
      SEMVER_CURRENT_TAG = :SEMVER_CURRENT_TAG
      SEMVER_BUMP_TYPE = :SEMVER_BUMP_TYPE
      SEMVER_NEW_VERSION = :SEMVER_NEW_VERSION
      SEMVER_NEW_CHANGELOG = :SEMVER_NEW_CHANGELOG
      SEMVER_BUMPABLE = :SEMVER_BUMPABLE
      SEMVER_VERSIONING_SYSTEM = :SEMVER_VERSIONING_SYSTEM
    end

    # Action to retrieve semantic versioning information from commit history.
    class GetVersioningInfoAction < Action
      def self.run(params)
        params[:allowed_types].map!(&:to_sym)
        params[:bump_map].transform_keys!(&:to_sym)
        params[:bump_map].transform_values!(&:to_sym)
        params[:force_type] = params[:force_type]&.to_sym

        verify_type_map(params[:type_map])
        verify_bump_map(params[:bump_map])
        Helper::SemanticVersioningHelper.verify_versioning_system(params[:versioning_system])

        system = lane_context[SharedValues::SEMVER_VERSIONING_SYSTEM] = params[:versioning_system]
        target = params[:target]

        current_version = if params[:update]
                            Helper::SemanticVersioningHelper.previous_version(tag_format: params[:tag_format])
                          else
                            Helper::SemanticVersioningHelper.version_number(system: system, target: target)
                          end
        formatted_tag = Helper::SemanticVersioningHelper.formatted_tag(current_version, params[:tag_format])

        commits = Helper::SemanticVersioningHelper.git_commits(
          from: Helper::SemanticVersioningHelper.git_tag_exists?(formatted_tag) ? formatted_tag : nil,
          allowed_types: params[:allowed_types],
          bump_map: params[:bump_map]
        )

        bump_type = Helper::SemanticVersioningHelper.bump_type(commits: commits, force_type: params[:force_type])
        new_version = Helper::SemanticVersioningHelper.increase_version(current_version: current_version,
                                                                        bump_type: bump_type)
        new_changelog = Helper::SemanticVersioningHelper.build_changelog(version: new_version, commits: commits,
                                                                         type_map: params[:type_map])
        bumpable = current_version != new_version

        Actions.lane_context[SharedValues::SEMVER_CURRENT_VERSION] = current_version
        Actions.lane_context[SharedValues::SEMVER_CURRENT_TAG] = formatted_tag
        Actions.lane_context[SharedValues::SEMVER_BUMP_TYPE] = bump_type
        Actions.lane_context[SharedValues::SEMVER_NEW_VERSION] = new_version
        Actions.lane_context[SharedValues::SEMVER_NEW_CHANGELOG] = new_changelog
        Actions.lane_context[SharedValues::SEMVER_BUMPABLE] = bumpable

        bumpable
      end

      # :nocov:
      def self.description
        "Retrieve semantic versioning information from commit history."
      end

      def self.authors
        ["kassi"]
      end

      def self.output
        # Define the shared values you are going to provide
        [
          ["SEMVER_CURRENT_VERSION", "Current version of the project as provided"],
          ["SEMVER_CURRENT_TAG", "Current tag for the current version number"],
          ["SEMVER_BUMP_TYPE", "Type of version bump. One of major, minor, or patch"],
          ["SEMVER_NEW_VERSION", "New version that would have to be set from current version and commits"],
          ["SEMVER_NEW_CHANGELOG", "New changelog section for the new bump"],
          ["SEMVER_BUMPABLE", "True if a version bump is possible"],
          ["SEMVER_VERSIONING_SYSTEM", "The versioning system used"]
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns true, if the determined next version is higher than the current one."
      end

      def self.details
        # Optional:
        "Reads commits from last version and determines next version and changelog."
      end
      # :nocov:

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :allowed_types,
                                       env_name: "SEMANTIC_VERSIONING_ALLOWED_TYPES",
                                       description: "List of allowed commit types",
                                       optional: true,
                                       default_value: %w[build ci docs feat fix perf refactor style test chore revert
                                                         bump init],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :bump_map,
                                       description: "Map of commit types to their bump level (major, minor, patch)",
                                       optional: true,
                                       default_value: { breaking: :major, feat: :minor, fix: :patch },
                                       is_string: false,
                                       verify_block: ->(value) { verify_bump_map(value) }),
          FastlaneCore::ConfigItem.new(key: :force_type,
                                       env_name: "SEMANTIC_VERSIONING_FORCE_TYPE",
                                       description: "Force a minimum bump type",
                                       optional: true,
                                       default_value: nil,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :tag_format,
                                       env_name: "SEMANTIC_VERSIONING_TAG_FORMAT",
                                       description: "The format for the git tag",
                                       optional: true,
                                       default_value: "$version",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :target,
                                       env_name: "SEMANTIC_VERSIONING_TARGET",
                                       description: "Name of the target to use for manual versioning system",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :type_map,
                                       env_name: "SEMANTIC_VERSIONING_TYPE_MAP",
                                       description: "Map of types to section titles for the changelog." \
                                                    "Only the specified types will be used for the changelog",
                                       optional: true,
                                       default_value: { breaking: "BREAKING CHANGES", feat: "Features",
                                                        fix: "Bug Fixes" },
                                       is_string: false,
                                       verify_block: ->(value) { verify_type_map(value) }),
          FastlaneCore::ConfigItem.new(key: :update,
                                       env_name: "SEMANTIC_VERSIONING_UPDATE",
                                       description: "When set, the changelog is determined from the previous rather than current version." \
                                                    "This is useful when being on a release branch where new commits are added to the " \
                                                    "current release",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
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

      def self.verify_type_map(value)
        UI.user_error!("Parameter 'type_map' must be a Hash.") unless value.is_a?(Hash)
      end

      def self.verify_bump_map(value)
        UI.user_error!("Parameter 'bump_map' must be a Hash.") unless value.is_a?(Hash)
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        %i[ios mac].include?(platform)
      end
    end
  end
end

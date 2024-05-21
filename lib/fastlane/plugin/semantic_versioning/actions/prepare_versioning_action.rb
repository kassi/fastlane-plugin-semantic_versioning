# frozen_string_literal: true

require "fastlane/action"
require_relative "../helper/semantic_versioning_helper"

module Fastlane
  module Actions
    # Action to prepare the Xcode project for automatic versioning
    class PrepareVersioningAction < Action
      def self.run(params)
        xcodeproj_path = params[:xcodeproj] || Dir.glob("*.xcodeproj").first

        Fastlane::UI.user_error!("Unable to determine *.xcodeproj and no :xcodeproj specified") if xcodeproj_path.nil?

        project = Helper::SemanticVersioningHelper.project(xcodeproj_path)
        target = Helper::SemanticVersioningHelper.main_target
        main_group = Helper::SemanticVersioningHelper.main_group

        info_plist_file = File.join(main_group.path, "Info.plist")
        info_plist_path = File.join(project.path.dirname, info_plist_file)

        current_version = Fastlane::Actions::GetVersionNumberAction.run(xcodeproj: xcodeproj_path)
        Helper::SemanticVersioningHelper.ensure_info_plist(info_plist_path)
        %w[CFBundleVersion CFBundleShortVersionString].each do |key|
          unless Fastlane::Actions::GetInfoPlistValueAction.run(path: info_plist_path, key: key)
            Fastlane::Actions::SetInfoPlistValueAction.run(path: info_plist_path, key: key, value: current_version)
          end
        end

        target.build_configurations.each do |config|
          config.build_settings["VERSIONING_SYSTEM"] = "apple-generic"
          config.build_settings.delete("MARKETING_VERSION")
          config.build_settings.delete("GENERATE_INFOPLIST_FILE")
        end

        project.save
        true
      end

      # :nocov:
      def self.description
        "Prepares the Xcodeproject to be used with automatic versioning by tools."
      end

      def self.authors
        ["kassi"]
      end

      def self.output
        # Define the shared values you are going to provide
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Truthy value when everything worked out well."
      end

      def self.details
        # Optional:
        "Changes the versioning style and makes sure that version information is extracted into Info.plist " \
          "to be used with agvtool"
      end
      # :nocov:

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :main_group,
                                       env_name: "SEMANTIC_VERSIONING_MAIN_GROUP",
                                       description: "The name of the main group of the xcode project",
                                       optional: true,
                                       default_value: nil,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :xcodeproj,
                                       env_name: "SEMANTIC_VERSIONING_PROJECT",
                                       description: "The path to your project file (Not the workspace). Optional if you have only one",
                                       optional: true,
                                       default_value: nil,
                                       verify_block: proc do |value|
                                         if value.end_with?(".xcworkspace")
                                           UI.user_error!("Please pass the path to the project, not the workspace")
                                         end
                                         UI.user_error!("Could not find Xcode project") unless File.exist?(value)
                                       end)
        ]
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

# frozen_string_literal: true

require "fastlane_core/ui/ui"
require "fastlane/actions/get_version_number"
require "fastlane/actions/last_git_tag"
require "fastlane/plugin/versioning"
require "git"
require "xcodeproj"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class SemanticVersioningHelper
      # class methods that you define here become available in your action
      # as `Helper::SemanticVersioningHelper.your_method`
      #
      def self.version_number(system:, target:)
        if system == "apple-generic"
          Actions::GetVersionNumberAction.run({})
        else
          Actions::GetVersionNumberFromXcodeprojAction.run(target: target)
        end
      end

      def self.set_version_number(version_number:, system:)
        if system == "apple-generic"
          Fastlane::Actions::IncrementVersionNumberAction.run(version_number: version_number)
        else
          Actions::IncrementVersionNumberInXcodeprojAction.run(version_number: version_number)
        end
      end

      def self.previous_version(tag_format:)
        tag = Fastlane::Actions::LastGitTagAction.run(pattern: tag_format.sub("$version", "[0-9].[0-9].[0-9]"))
        return "0.0.0" if tag.empty?

        regex = tag_format.sub("$version", "(?<version>\\d+\\.\\d+\\.\\d+)")
        tag.match(regex) do |match|
          return match[:version]
        end
      end

      def self.verify_versioning_system(value)
        allowed = %w[apple-generic manual]
        return if allowed.include?(value)

        UI.user_error!("'versioning_system' must be one of #{allowed}")
      end

      def self.formatted_tag(tag, format)
        format.sub("$version", tag)
      end

      # Retrieves git commits and returns them grouped by type
      def self.git_commits(from:, allowed_types:, bump_map:)
        logs = from ? git.log(-1).between(from) : git.log(-1)
        logs.reverse_each.filter_map { |commit|
          parse_conventional_commit(commit: commit, allowed_types: allowed_types, bump_map: bump_map)
        }
      end

      def self.parse_conventional_commit(commit:, allowed_types:, bump_map:)
        types = allowed_types.join("|")
        commit.message.match(/^(?<type>#{types})(\((?<scope>\S+)\))?(?<major>!)?:\s+(?<subject>[^\n\r]+)(\z|\n\n(?<body>.*\z))/m) do |match|
          cc = {
            type: match[:type].to_sym,
            major: !match[:major].nil?,
            scope: match[:scope],
            subject: match[:subject],
            body: match[:body],
            breaking: nil,
            original_message: commit.message
          }

          match[:body]&.match(/^BREAKING CHANGE?: (.+)\z/) do |breaking|
            cc[:breaking] = breaking[1]
          end

          cc[:bump] = commit_bump_type(commit: cc, bump_map: bump_map)

          return cc
        end
      end

      def self.commit_bump_type(commit:, bump_map:)
        return :major if commit[:major]

        return bump_map[:breaking] if commit[:breaking]

        bump_map[commit[:type]]
      end

      def self.bump_type(commits:, force_type: nil)
        return force_type if force_type == :major # can't go any higher

        result = force_type

        commits.each do |commit|
          return :major if commit[:major]

          bump_type = commit[:bump]
          if bump_type == :major
            return :major
          elsif bump_type == :minor
            result = :minor
          elsif bump_type == :patch && result.nil?
            result = :patch
          end
        end

        result
      end

      def self.group_commits(commits:, allowed_types:)
        result = allowed_types.to_h { |type| [type, []] }
        result[:none] = []

        commits.each do |commit|
          result[:breaking] << commit if commit[:breaking] && allowed_types.include?(:breaking)

          if commit[:major] && !allowed_types.include?(commit[:type])
            result[:none] << commit
            next
          end

          next unless allowed_types.include?(commit[:type])

          result[commit[:type]] << commit
        end

        result
      end

      def self.increase_version(current_version:, bump_type:)
        version_array = current_version.split(".").map(&:to_i)
        version_array = version_array.unshift(0, 0)[-3..] # pad from left with zeros when version is not 3-digits.

        case bump_type
        when :major
          version_array[0] += 1
          version_array[1] = version_array[2] = 0
        when :minor
          version_array[1] += 1
          version_array[2] = 0
        when :patch
          version_array[2] += 1
        end

        version_array.join(".")
      end

      # Builds and returns th changelog for the upcoming release.
      def self.build_changelog(version:, commits:, type_map:, name: nil)
        lines = []

        title = [version, name, Time.now.strftime("(%F)")].compact.join(" ")
        lines << "## #{title}"
        lines << ""

        grouped_commits = group_commits(commits: commits, allowed_types: type_map.keys)
        grouped_commits.each do |key, section_commits|
          next unless section_commits.any?

          lines << "### #{type_map[key]}:" if key != :none
          lines << ""

          section_commits.each do |commit|
            lines << "- #{key == :breaking ? commit[:breaking] : commit[:subject]}"
          end

          lines << ""
        end

        "#{lines.join("\n")}\n"
      end

      def self.write_changelog(path:, changelog:)
        old_changelog = File.new(path).read if File.exist?(path)

        File.open(path, "w") do |file|
          file.write(changelog)
          if old_changelog
            file.write("\n")
            file.write(old_changelog)
          end
        end
      end

      def self.bump_message(format)
        format("bump: %s", format
          .sub("$current_version", Actions.lane_context[Actions::SharedValues::SEMVER_CURRENT_VERSION])
          .sub("$new_version", Actions.lane_context[Actions::SharedValues::SEMVER_NEW_VERSION]))
      end

      def self.git
        # rubocop:disable Style/ClassVars
        @@git ||= Git.open(".")
        # rubocop:enable Style/ClassVars
      end

      def self.git_tag_exists?(tag)
        git.tags.include?(tag)
      end

      def self.project(path = nil)
        # rubocop:disable Style/ClassVars
        @@project ||= Xcodeproj::Project.open(path)
        # rubocop:enable Style/ClassVars
      end

      def self.main_target
        project.targets.first
      end

      def self.main_group(name = nil)
        project.main_group[name || main_target.name]
      end

      def self.ensure_info_plist(path)
        return if File.exist?(path)

        File.write(path, <<-PLIST)
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
          </dict>
          </plist>
        PLIST

        info_plist = main_group.new_file("Info.plist")
        info_plist.include_in_index = nil
        info_plist.set_last_known_file_type("text.plist")
        main_target.build_configurations.each do |config|
          config.build_settings["INFOPLIST_FILE"] = info_plist.full_path.to_s
        end
      end
    end
  end
end

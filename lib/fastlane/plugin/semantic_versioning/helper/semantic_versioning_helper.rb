require "fastlane_core/ui/ui"
require "fastlane/actions/get_version_number"
require "git"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class SemanticVersioningHelper
      # class methods that you define here become available in your action
      # as `Helper::SemanticVersioningHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the semantic_versioning plugin helper!")
      end

      def self.version_number
        Actions::GetVersionNumberAction.run({})
      end

      def self.formatted_tag(tag, format)
        format.sub("$version", tag)
      end

      def self.git_tag_exists?(tag)
        git.tags.include?(tag)
      end

      # Retrieves git commits and returns them grouped by type
      def self.git_commits(from:, allowed_types:)
        logs = from ? git.log(-1).between(from) : git.log(-1)
        logs.reverse_each.map do |commit|
          parse_conventional_commit(commit: commit, allowed_types: allowed_types)
        end.compact
      end

      def self.group_commits(commits:, allowed_types:)
        result = allowed_types.to_h { |type| [type, []] }

        commits.each do |commit|
          if commit[:breaking] && allowed_types.include?(:breaking)
            result[:breaking] << commit
          end
          next unless allowed_types.include?(commit[:type])

          # If the breaking change is made from the actual feature subject, don't repeat it.
          next if commit[:breaking] == commit[:subject]

          result[commit[:type]] << commit
        end

        return result
      end

      def self.bump_type(commits:, bump_map:)
        result = nil

        commits.each do |commit|
          bump_type = commit[:breaking] ? bump_map[:breaking] : bump_map[commit[:type]]
          if bump_type == :major
            return :major
          elsif bump_type == :minor
            result = :minor
          elsif bump_type == :patch && result.nil?
            result = :patch
          end
        end

        return result
      end

      def self.parse_conventional_commit(commit:, allowed_types:)
        types = allowed_types.join("|")
        commit.message.match(/^(?<type>#{types})(\((?<scope>\S+)\))?(?<breaking>!)?:\s+(?<subject>[^\n\r]+)(\z|\n\n(?<body>.*\z))/m) do |match|
          unless allowed_types.include?(match[:type].to_sym)
            UI.important("Commit #{commit.sha} has invalid type: #{match[:type]}. Ignoring")
            break
          end

          cc = {
            type: match[:type].to_sym,
            scope: match[:scope],
            subject: match[:subject],
            body: match[:body],
            breaking: match[:breaking] ? match[:subject] : nil,
            original_message: commit.message
          }

          match[:body]&.match(/^BREAKING CHANGE?: (.+)\z/) do |breaking|
            cc[:breaking] = breaking[1]
          end

          return cc
        end
      end

      def self.increase_version(current_version:, bump_type:)
        version_array = current_version.split(".").map(&:to_i)

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

        return version_array.join(".")
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

          lines << "### #{type_map[key]}:"
          lines << ""

          section_commits.each do |commit|
            lines << "- #{key == :breaking ? commit[:breaking] : commit[:subject]}"
          end

          lines << ""
        end

        return "#{lines.join("\n")}\n"
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

      def self.git_command(args)
        Actions.sh("git #{args.join(' ')}").chomp
      end

      def self.git
        # rubocop:disable Style/ClassVars
        @@git ||= Git.open(".")
        # rubocop:enable Style/ClassVars
      end
    end
  end
end

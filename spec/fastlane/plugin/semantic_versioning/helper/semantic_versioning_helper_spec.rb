# frozen_string_literal: true

require "git"

def raw_commit(message)
  indented_message = message.each_line.map { |e| "    #{e.chomp}" }.join("\n")
  header = <<-COMMIT.gsub("    ", "")
    commit 0d22b3b72c22951a804bffadc6fbdb55a99ca996
    tree bf7f08c7f932db12030e312689155bccc47c5bb3
    author Me <email@example.com> 1715848588 +0200
    committer Me <email@example.com> 1715848588 +0200

  COMMIT
  header + indented_message
end

describe Fastlane::Helper::SemanticVersioningHelper do
  describe ".parse_conventional_commit" do
    subject {
      described_class.parse_conventional_commit(commit: commit, allowed_types: allowed_types, bump_map: bump_map)
    }

    let(:allowed_types) { %i[build ci docs feat fix perf refactor style test chore revert bump init] }
    let(:bump_map) { { breaking: :major, feat: :minor, fix: :patch } }
    let(:message) { "" }
    let(:git) { Git.open(".") }
    let(:commit) { git.log(1).first }
    let(:process_result) { double(stdout: raw_commit(message)) }

    before do
      command_line = instance_double(Git::CommandLine)
      allow(Git::CommandLine).to receive(:new).and_return(command_line)
      allow(command_line).to receive(:run).and_return(process_result)
    end

    context "when the first line doesn't match" do
      let(:message) { "This is an invalid commit message" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when the body doesn't match" do
      let(:message) { "feat: new feature\ninvalid second line" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when the commit is a simple valid message" do
      let(:message) { "feat: add new feature" }

      it "returns the correct hash" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to be_nil
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to be_nil
        expect(subject[:breaking]).to be_nil
      end
    end

    context "when the commit is a valid message with scope" do
      let(:message) { "feat(my-scope): add new feature" }

      it "returns the correct hash" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to eq("my-scope")
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to be_nil
        expect(subject[:breaking]).to be_nil
      end
    end

    context "when the commit is a valid message with body" do
      let(:message) { "feat(my-scope): add new feature\n\nThis is the body\nCloses: #42" }

      it "returns the correct hash, setting the body" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to eq("my-scope")
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to eq("This is the body\nCloses: #42")
        expect(subject[:breaking]).to be_nil
      end
    end

    context "when the commit is a valid message with body and breaking change" do
      let(:message) {
        "feat(my-scope): add new feature\n\nThis is the body\nCloses: #42\n\nBREAKING CHANGE: It barfs everything"
      }

      it "returns the correct hash, setting breaking change message" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to eq("my-scope")
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to eq("This is the body\nCloses: #42\n\nBREAKING CHANGE: It barfs everything")
        expect(subject[:breaking]).to eq("It barfs everything")
      end
    end

    context "when the commit is a valid message with footer" do
      let(:message) { "feat(my-scope): add new feature\n\nThis is the body\nCloses: #42\n\nThe footer" }

      it "returns the correct hash, including body and footer into body" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to eq("my-scope")
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to eq("This is the body\nCloses: #42\n\nThe footer")
        expect(subject[:breaking]).to be_nil
      end
    end

    context "when the commit is a valid message with major bump exclamation for feat" do
      let(:message) { "feat(my-scope)!: add new feature" }

      it "returns the correct hash, setting the subject as feature" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to eq("my-scope")
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to be_nil
        expect(subject[:breaking]).to be_nil
      end
    end

    context "when the commit is a valid message with major bump exclamation for unsectioned type" do
      let(:message) { "bump!: first official release" }

      it "returns the correct hash, setting the subject as breaking change message" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:bump)
        expect(subject[:major]).to be_truthy
        expect(subject[:scope]).to be_nil
        expect(subject[:subject]).to eq("first official release")
        expect(subject[:body]).to be_nil
        expect(subject[:breaking]).to be_nil
      end
    end
  end

  describe ".bump_type" do
    subject { described_class.bump_type(commits: commits, force_type: force_type) }

    let(:commits) { types.map { |e| { bump: e } } }
    let(:force_type) { nil }

    context "when there are no relevant commits" do
      let(:types) { [nil, nil, nil] }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when there is at least one major bump commit" do
      let(:types) { [nil, :patch, :patch, :minor, :major, nil] }

      it "returns major" do
        expect(subject).to eq(:major)
      end
    end

    context "when there are several minor and patches commits" do
      let(:types) { [nil, :patch, :minor, :patch, :minor, nil] }

      it "returns minor" do
        expect(subject).to eq(:minor)
      end
    end

    context "when there only patches" do
      let(:types) { [nil, :patch, :patch, nil, :patch] }

      it "returns patch" do
        expect(subject).to eq(:patch)
      end
    end

    context "when there is a force type" do
      let(:types) { [nil, :patch, :patch, nil, :patch] }
      let(:force_type) { :major }

      it "returns major" do
        expect(subject).to eq(:major)
      end
    end
  end

  describe ".build_changelog" do
    subject { described_class.build_changelog(version: version, commits: commits, type_map: type_map) }

    let(:version) { "1.0.0" }
    let(:commits) { [] }
    let(:type_map) { { breaking: "BREAKING CHANGES", feat: "Features", fix: "Bug Fixes" } }
    let(:today) { Time.now.strftime("%F") }

    context "when there are no commits" do
      it "only writes a title with an empty line" do
        expect(subject).to eq("## 1.0.0 (#{today})\n\n")
      end
    end

    context "when there are breaking changes" do
      let(:commits) { [{ type: :feat, breaking: "this breaks", subject: "cool feature" }] }

      it "adds the breaking changes section with title" do
        expect(subject).to eq(
          "## 1.0.0 (#{today})\n\n### BREAKING CHANGES:\n\n- this breaks\n\n" \
          "### Features:\n\n- cool feature\n\n"
        )
      end
    end

    context "when there are many items for a section" do
      let(:commits) do
        [
          { type: :feat, breaking: "this breaks", subject: "cool feature" },
          { type: :fix, breaking: false, subject: "wrong value" },
          { type: :fix, breaking: false, subject: "wrong setting" },
          { type: :feat, breaking: false, subject: "other feature" },
          { type: :feat, breaking: "this breaks as well", subject: "changed feature" }
        ]
      end

      it "lists all items per section" do
        expect(subject).to eq(
          "## 1.0.0 (#{today})\n\n" \
          "### BREAKING CHANGES:\n\n" \
          "- this breaks\n" \
          "- this breaks as well\n\n" \
          "### Features:\n\n" \
          "- cool feature\n" \
          "- other feature\n" \
          "- changed feature\n\n" \
          "### Bug Fixes:\n\n" \
          "- wrong value\n" \
          "- wrong setting\n\n"
        )
      end
    end

    context "when there is a major bump commit of a non listed type" do
      let(:commits) do
        [
          { type: :feat, subject: "cool feature" },
          { type: :fix, subject: "wrong value" },
          { type: :fix, subject: "wrong setting" },
          { type: :bump, major: true, subject: "this is the first official release" },
          { type: :feat, subject: "other feature" },
          { type: :feat, subject: "changed feature" }
        ]
      end

      it "shows the subject in an additional empty section" do
        expect(subject).to eq(
          "## 1.0.0 (#{today})\n\n" \
          "### Features:\n\n" \
          "- cool feature\n" \
          "- other feature\n" \
          "- changed feature\n\n" \
          "### Bug Fixes:\n\n" \
          "- wrong value\n" \
          "- wrong setting\n\n" \
          "\n" \
          "- this is the first official release\n\n"
        )
      end
    end
  end

  describe ".ensure_info_plist" do
    subject { described_class.ensure_info_plist(path) }

    let(:path) { "MyGroup/Info.plist" }
    let(:xcodeproj_file) { fixture("Valid.xcodeproj") }

    context "when Info.plist exists" do
      before do
        allow(File).to receive(:exist?).with(path).and_return(true)
        allow(File).to receive(:write)
      end

      it "does not touch and file" do
        subject
        expect(File).not_to have_received(:write)
      end
    end

    context "when Info.plist does not exists" do
      let(:project) { described_class.project(xcodeproj_file) }

      before do
        project
        allow(File).to receive(:exist?).with(path).and_return(false)
        allow(File).to receive(:write)
        subject
      end

      it "writes a new file with content" do
        expect(File).to have_received(:write).with(path, match(/<plist version=/))
      end

      # rubocop:disable RSpec/ExampleLength
      it "adds a file reference to xcodeproj's main group" do
        expect(project.to_tree_hash).to match(hash_including(
                                                "rootObject" => hash_including(
                                                  "mainGroup" => hash_including(
                                                    "children" => include(
                                                      hash_including(
                                                        "displayName" => "Valid",
                                                        "children" => include(
                                                          "displayName" => "Info.plist",
                                                          "isa" => "PBXFileReference",
                                                          "path" => "Info.plist",
                                                          "sourceTree" => "<group>",
                                                          "lastKnownFileType" => "text.plist"
                                                        )
                                                      )
                                                    )
                                                  )
                                                )
                                              ))
      end

      it "adds a INFOPLIST_FILE to each build_setting" do
        expect(project.to_tree_hash).to match(hash_including(
                                                "rootObject" => hash_including(
                                                  "targets" => include(
                                                    hash_including(
                                                      "displayName" => "Valid",
                                                      "buildConfigurationList" => hash_including(
                                                        "buildConfigurations" => include(
                                                          hash_including({
                                                                           "name" => "Release",
                                                                           "buildSettings" => hash_including(
                                                                             "INFOPLIST_FILE" => "Valid/Info.plist"
                                                                           )
                                                                         }),
                                                          hash_including(
                                                            "name" => "Debug",
                                                            "buildSettings" => hash_including(
                                                              "INFOPLIST_FILE" => "Valid/Info.plist"
                                                            )
                                                          )
                                                        )
                                                      )
                                                    )
                                                  )
                                                )
                                              ))
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end

  describe ".increase_version" do
    subject { described_class.increase_version(current_version: current_version, bump_type: bump_type) }

    context "when current version is semver" do
      let(:current_version) { "1.2.3" }

      context "when bump type is major" do
        let(:bump_type) { :major }

        it "returns the correct version" do
          expect(subject).to eq("2.0.0")
        end
      end

      context "when bump type is minor" do
        let(:bump_type) { :minor }

        it "returns the correct version" do
          expect(subject).to eq("1.3.0")
        end
      end

      context "when bump type is patch" do
        let(:bump_type) { :patch }

        it "returns the correct version" do
          expect(subject).to eq("1.2.4")
        end
      end
    end

    context "when current version is standard xcode format" do
      let(:current_version) { "1.0" }

      context "when bump type is major" do
        let(:bump_type) { :major }

        it "returns the correct version" do
          expect(subject).to eq("1.0.0")
        end
      end

      context "when bump type is minor" do
        let(:bump_type) { :minor }

        it "returns the correct version" do
          expect(subject).to eq("0.2.0")
        end
      end

      context "when bump type is patch" do
        let(:bump_type) { :patch }

        it "returns the correct version" do
          expect(subject).to eq("0.1.1")
        end
      end
    end
  end
end

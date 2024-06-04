# frozen_string_literal: true

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

def map_default_params
  described_class.available_options.select(&:optional).to_h { |e| [e.key, e.default_value] }
end

describe Fastlane::Actions::GetVersioningInfoAction do
  describe ".run" do
    subject { described_class.run(default_params) }

    let(:current_version) { "0.1.0" }
    let(:messages) { [] }
    let(:tags) { "" }
    let(:command_line) { instance_double(Git::CommandLine) }

    before do
      allow(Git::CommandLine).to receive(:new).and_return(command_line)
      allow(command_line).to receive(:run).with("tag", hash_including).and_return(double(stdout: tags))
      allow(command_line).to receive(:run).with(*%w[log --max-count=-1 --no-color --pretty=raw], hash_including) {
        double(stdout: messages.map { |message| raw_commit(message) }.join("\n"))
      }

      allow(Fastlane::Actions).to receive(:sh).with("git rev-parse -q --verify refs/tags/v0.1.0",
                                                    any_args).and_return("26671545a3cc6b044fa5cfa93d31cc569786d933")
    end

    after do
      # rubocop:disable Style/ClassVars
      Fastlane::Helper::SemanticVersioningHelper.class_variable_set(:@@git, nil)
      # rubocop:enable Style/ClassVars
    end

    %w[apple-generic manual].each do |system|
      context "when #{system} versioning system is used" do
        let(:default_params) { map_default_params.merge(tag_format: "v$version", versioning_system: system) }

        before do
          if system == "apple-generic"
            allow(Fastlane::Actions::GetVersionNumberAction).to receive(:run) { current_version }
          else
            allow(Fastlane::Actions::GetVersionNumberFromXcodeprojAction).to receive(:run) { current_version }
          end
        end

        it "returns false and sets shared values correctly" do
          expect(subject).to be_falsy
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_CURRENT_VERSION]).to eq("0.1.0")
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_CURRENT_TAG]).to eq("v0.1.0")
          expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_falsy
        end

        context "when the version number is default 2-digit" do
          let(:current_version) { "1.0" }

          context "when a major bump is triggered" do
            let(:messages) { ["bump!: first official release"] }

            it "jumps to 1.0.0" do
              expect(subject).to be_truthy
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("1.0.0")
            end
          end

          context "when a minor bump is triggered" do
            let(:messages) { ["feat: my feature"] }

            it "jumps to 0.2.0" do
              expect(subject).to be_truthy
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("0.2.0")
            end
          end

          context "when a patch bump is triggered" do
            let(:messages) { ["fix: my fix"] }

            it "jumps to 0.1.1" do
              expect(subject).to be_truthy
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("0.1.1")
            end
          end
        end

        context "when there are breaking changes" do
          let(:messages) do
            [
              "feat: incredible change\n\nBREAKING CHANGE: this breaks everything",
              "feat: other feature",
              "feat(scope): scoped feature",
              "build: just build",
              "fix: bugfix",
              "fix(scope): scoped bugfix"
            ]
          end

          it "increases major version number for next version" do
            expect(subject).to be_truthy
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:major)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("1.0.0")
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_CHANGELOG]).to match(/\A## 1.0.0/)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
          end
        end

        context "when there are feature changes" do
          let(:messages) do
            [
              "feat: incredible change\n\nno BREAKING CHANGE: nothing",
              "feat: other feature",
              "feat(scope): scoped feature",
              "build: just build",
              "fix: bugfix",
              "fix(scope): scoped bugfix"
            ]
          end

          it "increases minor version number for next version" do
            expect(subject).to be_truthy
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:minor)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("0.2.0")
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_CHANGELOG]).to match(/\A## 0.2.0/)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
          end
        end

        context "when there are bug fix changes" do
          let(:messages) do
            [
              "build: just build",
              "fix: bugfix",
              "fix(scope): scoped bugfix"
            ]
          end

          it "increases patch version number for next version" do
            expect(subject).to be_truthy
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:patch)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("0.1.1")
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
          end
        end

        context "when there are bug fix changes and a force type" do
          let(:default_params) { map_default_params.merge(force_type: "major", versioning_system: system) }
          let(:messages) do
            [
              "build: just build",
              "fix: bugfix",
              "fix(scope): scoped bugfix"
            ]
          end

          it "increases major version number for next version" do
            expect(subject).to be_truthy
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:major)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("1.0.0")
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
          end
        end

        context "when there is a force major bump commit for a listed type" do
          let(:messages) do
            [
              "feat!: bundle for first initial version"
            ]
          end

          it "increases major version number for next version and adds feature to changelog" do
            expect(subject).to be_truthy
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:major)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("1.0.0")
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_CHANGELOG]).to eq(
              "## 1.0.0 (#{Time.now.strftime('%F')})\n\n" \
              "### Features:\n\n" \
              "- bundle for first initial version\n\n"
            )
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
          end
        end

        context "when there is a force major bump commit for a non listed type" do
          let(:messages) do
            [
              "bump!: bundle for first initial version"
            ]
          end

          it "increases major version number for next version and includes an unsectioned commit in the changelog" do
            expect(subject).to be_truthy
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:major)
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("1.0.0")
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_CHANGELOG]).to eq(
              "## 1.0.0 (#{Time.now.strftime('%F')})\n\n" \
              "\n" \
              "- bundle for first initial version\n\n"
            )
            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
          end
        end
      end
    end

    context "when update flag is used" do
      let(:default_params) { map_default_params.merge(update: true) }
      let(:messages) { ["feat: my feature"] }

      before do
        allow(Fastlane::Actions::LastGitTagAction).to receive(:run).and_return("")
      end

      it "returns success with correct values" do
        expect(subject).to be_truthy
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("0.1.0")
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_CHANGELOG]).to match(
          /- my feature/
        )
      end
    end
  end

  describe ".is_supported?" do
    subject { described_class.is_supported?(platform) }

    context "when platform is ios" do
      let(:platform) { :ios }

      it "returns true" do
        expect(subject).to be_truthy
      end
    end

    context "when platform is mac" do
      let(:platform) { :mac }

      it "returns true" do
        expect(subject).to be_truthy
      end
    end

    context "when platform is android" do
      let(:platform) { :android }

      it "returns false" do
        expect(subject).to be_falsy
      end
    end
  end
end

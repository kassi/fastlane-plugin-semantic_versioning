def raw_commit(message)
  indented_message = message.each_line.map { |e| "    #{e.chomp}" }.join("\n")
  header = <<-COMMIT.gsub("    ", "")
    commit 0d22b3b72c22951a804bffadc6fbdb55a99ca996
    tree bf7f08c7f932db12030e312689155bccc47c5bb3
    author Me <email@example.com> 1715848588 +0200
    committer Me <email@example.com> 1715848588 +0200

  COMMIT
  return header + indented_message
end

def map_default_params
  described_class.available_options.select(&:optional).to_h { |e| [e.key, e.default_value] }
end

describe Fastlane::Actions::GetVersioningInfoAction do
  describe ".run" do
    subject { described_class.run(default_params) }

    let(:default_params) { map_default_params.merge(tag_format: "v$version") }
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
      allow(Fastlane::Actions::GetVersionNumberAction).to receive(:run) { current_version }
      allow(Fastlane::Actions).to receive(:sh).with("git rev-parse -q --verify refs/tags/v0.1.0", any_args) {
        "26671545a3cc6b044fa5cfa93d31cc569786d933"
      }
    end

    after do
      # rubocop:disable Style/ClassVars
      Fastlane::Helper::SemanticVersioningHelper.class_variable_set(:@@git, nil)
      # rubocop:enable Style/ClassVars
    end

    it "returns false and sets shared values correctly" do
      expect(subject).to be_falsy
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_CURRENT_VERSION]).to eq("0.1.0")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_CURRENT_TAG]).to eq("v0.1.0")
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_falsy
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
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
      end
    end

    context "when there are fixes changes" do
      let(:messages) do
        [
          "build: just build",
          "fix: bugfix",
          "fix(scope): scoped bugfix"
        ]
      end

      it "increases minor version number for next version" do
        expect(subject).to be_truthy
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMP_TYPE]).to eq(:patch)
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION]).to eq("0.1.1")
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE]).to be_truthy
      end
    end
  end
end

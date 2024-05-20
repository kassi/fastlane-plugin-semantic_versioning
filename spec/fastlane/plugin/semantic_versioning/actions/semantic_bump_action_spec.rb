# frozen_string_literal: true

def map_default_params
  described_class.available_options.select(&:optional).to_h { |e| [e.key, e.default_value] }
end

describe Fastlane::Actions::SemanticBumpAction do
  describe ".run" do
    subject { described_class.run(default_params) }

    let(:default_params) { map_default_params.merge(tag_format: "v$version") }

    context "when get_versioning_info hasn't been called" do
      before do
        Fastlane::Actions.lane_context.delete(Fastlane::Actions::SharedValues::SEMVER_BUMPABLE)
      end

      it "aborts with an error" do
        expect { subject }.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    context "when get_versioning_info reveals no bump needed" do
      before do
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE] = false
        allow(Fastlane::UI).to receive(:message).with("No version bump detected.")
        allow(Fastlane::Helper::SemanticVersioningHelper).to receive(:write_changelog)
        allow(Fastlane::Actions::CommitVersionBumpAction).to receive(:run)
      end

      it "returns false and doesn't change anything" do
        expect(subject).to be_falsy
        expect(Fastlane::UI).to have_received(:message).with("No version bump detected.")
        expect(Fastlane::Helper::SemanticVersioningHelper).not_to have_received(:write_changelog)
        expect(Fastlane::Actions::CommitVersionBumpAction).not_to have_received(:run)
      end
    end

    context "when get_versioning_info reveals a new version" do
      before do
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_BUMPABLE] = true
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_CURRENT_VERSION] = "0.1.0"
        Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SEMVER_NEW_VERSION] = "0.2.0"

        allow(Fastlane::Actions).to receive(:sh) { |*args|
          if /agvtool what-marketing-version -terse1$/.match?(args[0])
            "agvtool what-marketing-version -terse1\n0.1.0"
          elsif args[0] == "git rev-parse --show-toplevel"
            "/path/to/project"
          end
        }
        allow(Fastlane::Helper::SemanticVersioningHelper).to receive(:write_changelog)
        allow(Fastlane::Actions::CommitVersionBumpAction).to receive(:run)
      end

      it "returns true and updated version and changelog" do
        expect(subject).to be_truthy
        expect(Fastlane::Helper::SemanticVersioningHelper).to have_received(:write_changelog)
        expect(Fastlane::Actions::CommitVersionBumpAction).to have_received(:run)
      end
    end
  end
end

# frozen_string_literal: true

require "xcodeproj"

def map_default_params
  described_class.available_options.select(&:optional).to_h { |e| [e.key, e.default_value] }
end

describe Fastlane::Actions::PrepareVersioningAction do
  describe ".run" do
    subject { described_class.run(default_params) }

    let(:default_params) { map_default_params }

    context "when no xcodeproj is determined" do
      before do
        allow(Fastlane::UI).to receive(:user_error!).and_call_original
      end

      it "raises an error" do
        expect { subject }.to raise_error(FastlaneCore::Interface::FastlaneError)
        expect(Fastlane::UI).to have_received(:user_error!).with("Unable to determine *.xcodeproj and no :xcodeproj specified")
      end
    end

    # rubocop:disable RSpec::AnyInstance
    context "when xcodeproj is available" do
      let(:default_params) { map_default_params.merge(xcodeproj: xcodeproj_file) }
      let(:xcodeproj_file) { fixture("valid.xcodeproj") }

      before do
        allow_any_instance_of(Xcodeproj::Project).to receive(:save)
        allow(File).to receive(:write)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(match(/Info\.plist$/)).and_return(false, true)
      end

      it "saves correctly" do
        expect_any_instance_of(Xcodeproj::Project).to receive(:save)
        expect(subject).to be_truthy
        expect(File).to have_received(:write).with(
          match(/Info\.plist$/),
          match(%r{CFBundleVersion.*<string>1.0</string>.*CFBundleShortVersionString.*<string>1.0</string>}m)
        )
      end
    end
    # rubocop:enable RSpec::AnyInstance
  end
end

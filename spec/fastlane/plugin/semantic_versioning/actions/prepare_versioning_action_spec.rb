# frozen_string_literal: true

require "fakefs/safe"
require "xcodeproj"

def map_default_params
  described_class.available_options.select(&:optional).to_h { |e| [e.key, e.default_value] }
end

describe Fastlane::Actions::PrepareVersioningAction do
  describe ".run" do
    subject { described_class.run(default_params) }

    let(:default_params) { map_default_params.merge(xcodeproj: xcodeproj_file) }
    let(:xcodeproj_file) { fixture("Valid.xcodeproj") }

    after do
      # rubocop:disable Style/ClassVars
      Fastlane::Helper::SemanticVersioningHelper.class_variable_set(:@@project, nil)
      # rubocop:enable Style/ClassVars
    end

    context "when no xcodeproj is determined" do
      let(:default_params) { map_default_params }

      before do
        allow(Fastlane::UI).to receive(:user_error!).and_call_original
      end

      it "raises an error" do
        expect { subject }.to raise_error(FastlaneCore::Interface::FastlaneError)
        expect(Fastlane::UI).to have_received(:user_error!).with("Unable to determine *.xcodeproj and no :xcodeproj specified")
      end
    end

    # rubocop:disable RSpec/AnyInstance
    context "when xcodeproj is available" do
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
          match(/1\.0/m)
        )
      end
    end
    # rubocop:enable RSpec/AnyInstance

    context "when Info.plist exists" do
      let(:xcodeproj_file) { "Valid.xcodeproj" }

      before do
        info_plist_content = fixture(fixture_file).read
        pbxproj_content = fixture("Valid.xcodeproj/project.pbxproj").read

        _ = Xcodeproj::Project
        # Xcodeproj uses this library for atomic writes.
        # This causes problems with FakeFS when using standard tmpdir.
        allow(Atomos).to receive(:default_tmpdir_for_file) { |dest, _|
          File.dirname(dest)
        }

        FakeFS.activate!
        FakeFS.clear!

        # File.expand_path
        Dir.mkdir("Valid")
        File.write("Valid/Info.plist", info_plist_content)
        Dir.mkdir("Valid.xcodeproj")
        File.write("Valid.xcodeproj/project.pbxproj", pbxproj_content)
      end

      after do
        FakeFS.deactivate!
      end

      context "when Info.plist does not contain version specifier" do
        let(:fixture_file) { "Info.plist.empty" }

        it "adds version specifier to existing Info.plist" do
          subject
          content = File.read("Valid/Info.plist")
          expect(content).to match(
            %r{<key>CFBundleVersion</key>\n\s*<string>1\.0</string>}m
          )
          expect(content).to match(
            %r{<key>CFBundleShortVersionString</key>\n\s*<string>1\.0</string>}m
          )
        end
      end

      context "when Info.plist does contain version specifier" do
        let(:fixture_file) { "Info.plist" }

        it "does not touch Info.plist file" do
          subject
          content = File.read("Valid/Info.plist")
          expect(content).to match(
            %r{<key>CFBundleVersion</key>\n\s*<string>3\.1</string>}m
          )
          expect(content).to match(
            %r{<key>CFBundleShortVersionString</key>\n\s*<string>3\.1</string>}m
          )
        end
      end
    end
  end
end

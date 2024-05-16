require "git"

def raw_commit(message)
  indented_message = message.each_line.map { |e| "    #{e.chomp}" }.join("\n")
  header = <<-EOS.gsub("    ", "")
    commit 0d22b3b72c22951a804bffadc6fbdb55a99ca996
    tree bf7f08c7f932db12030e312689155bccc47c5bb3
    author Me <email@example.com> 1715848588 +0200
    committer Me <email@example.com> 1715848588 +0200

  EOS
  return header + indented_message
end

describe Fastlane::Helper::SemanticVersioningHelper do

  describe ".parse_conventional_commit" do
    subject { described_class.parse_conventional_commit(commit: commit, allowed_types: allowed_types) }

    let(:allowed_types) { %i[build ci docs feat fix perf refactor style test chore revert bump init] }
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
      let(:message) { "feat(my-scope): add new feature\n\nThis is the body\nCloses: #42\n\nBREAKING CHANGE: It barfs everything" }

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

    context "when the commit is a valid message with breaking change exclamation" do
      let(:message) { "feat(my-scope)!: add new feature" }

      it "returns the correct hash, setting the subject as breaking change message" do
        expect(subject).not_to be_nil
        expect(subject[:type]).to eq(:feat)
        expect(subject[:scope]).to eq("my-scope")
        expect(subject[:subject]).to eq("add new feature")
        expect(subject[:body]).to be_nil
        expect(subject[:breaking]).to eq("add new feature")
      end
    end
  end

  fdescribe ".bump_type" do
    subject { described_class.bump_type(commits: commits, bump_map: bump_map) }

    let(:commits) { types.map { |t| t == :breaking ? { type: :feat, breaking: "x" } : { type: t} } }
    let(:bump_map) { { breaking: :major, feat: :minor, fix: :patch} }

    context "when there are no relevant commits" do
      let(:types) { %i[init build docs] }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when there is at least one breaking change commit" do
      let(:types) { %i[init build docs feat breaking build fix feat fix refactor] }

      it "returns major" do
        expect(subject).to eq(:major)
      end
    end

    context "when there are several feat and fix commits" do
      let(:types) { %i[init build docs feat feat build fix feat fix refactor] }

      it "returns minor" do
        expect(subject).to eq(:minor)
      end
    end

    context "when there only fixes" do
      let(:types) { %i[init build docs fix fix docs] }

      it "returns patch" do
        expect(subject).to eq(:patch)
      end
    end
  end
end

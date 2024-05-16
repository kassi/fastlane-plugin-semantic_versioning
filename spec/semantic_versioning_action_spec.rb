describe Fastlane::Actions::SemanticVersioningAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The semantic_versioning plugin is working!")

      Fastlane::Actions::SemanticVersioningAction.run(nil)
    end
  end
end

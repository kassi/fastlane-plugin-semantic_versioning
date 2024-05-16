lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/semantic_versioning/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-semantic_versioning'
  spec.version       = Fastlane::SemanticVersioning::VERSION
  spec.author        = 'Karsten Silkenbäumer'
  spec.email         = '993392+kassi@users.noreply.github.com'

  spec.summary       = 'Version and changelog management following semver and conventional commits.'
  spec.homepage      = "https://github.com/kassi/fastlane-plugin-semantic_versioning"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  spec.add_dependency 'git', '~> 2.0'
end

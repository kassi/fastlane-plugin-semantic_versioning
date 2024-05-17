# semantic_versioning plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-semantic_versioning)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-semantic_versioning`, add it to your project by running:

```bash
fastlane add_plugin semantic_versioning
```

## About semantic_versioning

Version and changelog management following semantic versioning and conventional commits.

The plugin provides two actions that have to be called in sequence, but therefore allow
additional interaction with the results before an actual commit is being made.

One example could be to get the version info for the upcoming release, and when this is
successful, i.e. a version bump is possible, create a release branch with that version number and
change to that branch before making any changes. Then call the `semantic_bump` action to create the commit on the release branch, before you may want to create a pull request for the new release.

Hint: You can also use the context to upload the changelog to AppStoreConnect afterwards. See the example `Fastfile` for more info.

### get_versioning_info

Call this in your lane to prepare a bump according to the rules. It will
- Determine next version number
- Build the changelog for the upcoming version bump

and provide this information in shared variables that are used in the second action.

### semantic_bump

Call this to actually bump the version, write the changelog and commit everything.

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

## Run tests for this plugin

To run both the tests, and code style validation, run

```
bundle exec rake
```

To automatically fix many of the styling issues, use
```
bundle exec rubocop -a
```

Or to start fast feedback development cycle:
```
bundle exec guard
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

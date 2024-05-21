## 3.0.2 (2024-05-21)

### Bug fixes

- standard xcode 2-digit version not treated as minor version

## 3.0.1 (2024-05-21)

### Bug fixes

- error when checking if plugin is supported for some actions

## 3.0.0 (2024-05-21)

### BREAKING CHANGE

- changes the default behavior of the actions to use manual instead of apple-generic versioning system

### Bug fixes

- plugin incorrecly reported android as being supported

### Features

- add option to use manual versioning system inside xcodeproj

## 2.1.1 (2024-05-21)

### Bug fixes

- prepare_versioning action leaves unbuildable xcode project

## 2.1.0 (2024-05-20)

### Features

- add prepare_versioning action for xcode projects

### Refactorings

- cleanup

## 2.0.0 (2024-05-18)

### BREAKING CHANGE

- exclamation bump type is not treated as a breaking change anymore

### Features

- allow major bumps with exclamation to appear in separate section
- add action parameter force_type to set a minimum bump type

### Refactorings

- remove unused code
- way of determining bump type

## 1.0.0 (2024-05-17)

### Features

- add action to bump the version and commit
- add building and writing changelog
- add bumpable output
- add action get_versioning_info

### Refactorings

- remove unused files
- align names of shared variables

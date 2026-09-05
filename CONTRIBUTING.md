# Contributing to the Flutter Cache Manager package

## What you will need

- A Linux, Mac OS X, or Windows machine (note: to run and compile iOS specific parts you'll need access to a Mac OS X machine);
- git (used for source version control, installation instruction can be found [here](https://git-scm.com/));
- The Flutter SDK (installation instructions can be found [here](https://flutter.io/get-started/install/));
- A personal GitHub account (if you don't have one, you can sign-up for free [here](https://github.com/))

## Setting up your development environment

- Fork `https://github.com/Baseflow/flutter_cache_manager` into your own GitHub account. If you already have a fork and moving to a new computer, make sure you update you fork.
- If you haven't configured your machine with an SSH key that's known to github, then
follow [GitHub's directions](https://help.github.com/articles/generating-ssh-keys/)
to generate an SSH key.
- Clone your forked repo on your local development machine: `git clone git@github.com:<your_name_here>/flutter_cache_manager.git`
- Change into the `flutter_cache_manager` directory: `cd flutter_cache_manager`
- Add an upstream to the original repo, so that fetch from the main repository and not your clone: `git remote add upstream git@github.com:Baseflow/flutter_cache_manager.git`

## Running the example project

- Change into the example directory for the package you are working on, e.g. `cd flutter_cache_manager/example`
- Run the App: `flutter run`

## Contribute

We really appreciate contributions via GitHub pull requests. To contribute take the following steps:

- Make sure you are up to date with the latest code on develop:
  - `git fetch upstream`
  - `git checkout upstream/develop -b <name_of_your_branch>`
- Apply your changes
- Verify your changes and fix potential warnings/ errors (run from the package you changed):
  - Check formatting: `dart format .`
  - Run static analyses: `flutter analyze`
  - Run unit-tests: `flutter test`
- Commit your changes: `git commit -am "<your informative commit message>"`
- Push changes to your fork: `git push origin <name_of_your_branch>`

Send us your pull request:

- Go to `https://github.com/Baseflow/flutter_cache_manager` and click the "Compare & pull request" button.

 Please make sure you solved all warnings and errors reported by the static code analyses and that you fill in the full pull request template. Failing to do so will result in us asking you to fix it.

## Pull request scope and versioning

Each pull request should follow these conventions:

- **One package per PR** — keep changes confined to a single package directory (`flutter_cache_manager/`, `flutter_cache_manager_firebase/`). Cross-package changes require maintainer coordination and are usually split into separate PRs.
- **Add CHANGELOG entry to [Unreleased]** — for your change, add one or more entries under the "Unreleased" section of that package's `CHANGELOG.md`. Entries should follow the style conventions also used by Flutter which can be found in their [CHANGELOG style guide](https://github.com/flutter/flutter/blob/master/docs/ecosystem/contributing/README.md#changelog-style).


# flutter_cache_manager agent instructions

Technical reference for AI agents and contributors developing in this repository.

Process and conduct live in their own files: contribution workflow in
[CONTRIBUTING.md](CONTRIBUTING.md), the [Contributor Covenant Code of
Conduct](CODE_OF_CONDUCT.md) (report unacceptable behavior to
[hello@baseflow.com](mailto:hello@baseflow.com)).

## Scope and stack

- This repo is the **Flutter Cache Manager** monorepo maintained by [Baseflow](https://baseflow.com).
- It contains two Dart packages (not a federated plugin). Work inside the **specific package** you are changing; there is no Melos or root pub workspace, and neither should be added unless the team decides to.
- Run Flutter and Dart commands with the same tooling CI uses (`flutter`, `dart`). Nothing in this repo requires anything else. If you happen to manage SDK versions locally with [fvm](https://fvm.app), prefix commands with `fvm`; that is a personal setup choice and is never checked in.

### Prerequisites

- Basic Dart and Flutter knowledge
- A working Flutter SDK installation (stable channel, matching CI — currently Flutter **3.47.4** in workflows)
- Comfort with filesystem / HTTP caching concepts helps, but is not required to start
- For running or building the example on iOS/macOS, access to a Mac is required
- Android example builds require JDK 17

### Reference documentation

This package is primarily a **Dart/Flutter library** (file download + disk cache), not a federated platform plugin. Prefer official Flutter/Dart docs and this repo's existing code for hands-on work:

- [Using packages](https://docs.flutter.dev/packages-and-plugins/using-packages)
- [Developing packages & plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Effective Dart](https://dart.dev/effective-dart)
- [pub versioning philosophy](https://dart.dev/tools/pub/versioning)

## Packages in this repo

| Package | Role |
|---------|------|
| `flutter_cache_manager` | Core cache manager: download, store, and serve files with configurable TTL / capacity |
| `flutter_cache_manager_firebase` | Optional `FileService` / cache manager integration for `firebase_storage` (`gs://` → HTTPS) |

There is no Melos workspace. Each package has its own `pubspec.yaml`, tests, and CI workflow.

## Architecture overview

```
App → CacheManager / DefaultCacheManager / custom Config
    → CacheStore (mem cache + CacheInfoRepository)
    → WebHelper + FileService (HTTP or custom, e.g. Firebase)
    → FileSystem (IO or memory on web)
```

Platform defaults for `CacheInfoRepository` (see `lib/src/config/_config_io.dart`):

- **Android / iOS / macOS** → `CacheObjectProvider` (sqflite)
- **Windows / Linux** → `JsonCacheInfoRepository`
- **Web** → non-storing provider

Custom `Config` can override `repo`, `fileSystem`, and `fileService`. Prefer extending or composing these abstractions rather than forking `CacheManager` internals.

**Persistence**: treat durability seriously — especially `JsonCacheInfoRepository` (full-file rewrite). Prefer serialized writes and atomic replace (temp + rename) over long debounce windows that can lose data on process kill. Do not reintroduce long debounce delays for JSON persistence without an explicit durability strategy (flush on close is not enough for force-stop).

## Authoritative project structure

- Root overview: `README.md` (symlink to `flutter_cache_manager/README.md`)
- Contribution workflow: `CONTRIBUTING.md`
- App-facing API: `flutter_cache_manager/lib/flutter_cache_manager.dart`
- Core manager: `flutter_cache_manager/lib/src/cache_manager.dart`
- Default / image managers: `flutter_cache_manager/lib/src/cache_managers/`
- Config (IO / web / unsupported): `flutter_cache_manager/lib/src/config/`
- In-memory + DB orchestration: `flutter_cache_manager/lib/src/cache_store.dart`
- Download / HTTP: `flutter_cache_manager/lib/src/web/`
- Cache metadata storage: `flutter_cache_manager/lib/src/storage/cache_info_repositories/`
  - `CacheObjectProvider` — sqflite (default on Android / iOS / macOS)
  - `JsonCacheInfoRepository` — JSON file (default on Windows / Linux)
  - `NonStoringObjectProvider` — web / no persistence
- File system abstraction: `flutter_cache_manager/lib/src/storage/file_system/`
- Firebase package: `flutter_cache_manager_firebase/lib/`
- Example app: `flutter_cache_manager/example/`
- CI:
  - `.github/workflows/build.yaml` — `flutter_cache_manager`
  - `.github/workflows/build-firebase.yaml` — `flutter_cache_manager_firebase`

## Where to make changes

- **Public API / docs for app developers** → `flutter_cache_manager/lib/` exports and `README.md`
- **Download / HTTP behavior** → `lib/src/web/`
- **Persistence / metadata** → `lib/src/storage/cache_info_repositories/`
- **Cache eviction / mem cache** → `lib/src/cache_store.dart`
- **Firebase integration** → `flutter_cache_manager_firebase/` only
- **Never** put Firebase-specific logic in `flutter_cache_manager`, or platform-specific logic in the core package when it belongs in config hooks or the Firebase package

Keep changes minimal in scope — one concern per change; match existing naming, error-handling (`FlutterError.reportError` where used), and testing patterns.

## Development setup

Per [CONTRIBUTING.md](CONTRIBUTING.md) and Baseflow's open-source forking workflow:

1. Fork `https://github.com/Baseflow/flutter_cache_manager` on GitHub.
2. Clone your fork: `git clone git@github.com:<your_name>/flutter_cache_manager.git`
3. Add upstream (the official repo you fetch from, not your fork):

```bash
git remote add upstream git@github.com:Baseflow/flutter_cache_manager.git
```

4. Branch from latest `develop`:

```bash
git fetch upstream
git checkout upstream/develop -b <name_of_your_branch>
```

Expected remotes after setup:

```
origin    git@github.com:<your_name>/flutter_cache_manager.git   # your fork (push here)
upstream  git@github.com:Baseflow/flutter_cache_manager.git      # official repo (fetch here)
```

## Commands

Run from the package you are editing:

```bash
cd flutter_cache_manager   # or flutter_cache_manager_firebase
flutter pub get
dart format .
flutter analyze
flutter test
```

CI runs the same commands with stricter flags:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
```

Run the example app:

```bash
cd flutter_cache_manager/example
flutter run
```

Before finishing work, run the same checks CI runs for that package (format, analyze, test; example builds are covered in `build.yaml` for the main package).

## Testing expectations

| Package | Tests |
|---------|-------|
| `flutter_cache_manager` | Dart unit tests under `test/` (manager, store, web helper, repositories, image helpers) |
| `flutter_cache_manager_firebase` | Minimal Dart tests — verify via analyze/format and integration judgment |

Prefer `MemoryFileSystem` / mocks over real disk or network in unit tests. When changing `JsonCacheInfoRepository`, cover persistence without relying on timers, and keep temp-file / failure paths in mind.

## Platform notes

- **Mobile / macOS**: default metadata store is sqflite (`CacheObjectProvider`).
- **Windows / Linux**: default metadata store is JSON (`JsonCacheInfoRepository`); writes should remain durable (write-through / short-lived queues, atomic replace).
- **Web**: limited / non-persisting storage via conditional imports (`_config_web.dart`, memory file system).
- **Firebase package**: depends on published `flutter_cache_manager`; local path overrides are only for integration experiments — do not assume Melos linking.

## Pull request workflow

This repo uses the **forking workflow**: contributors work on their own fork and open PRs to the main repository. Maintainers review and merge — do not push directly to `Baseflow/flutter_cache_manager`.

1. Apply changes on a branch based on `upstream/develop`.
2. Verify locally (from the changed package):
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
3. Push to your fork: `git push origin <name_of_your_branch>`
4. Open a PR against `Baseflow/flutter_cache_manager` and fill out the full [PR template](.github/PULL_REQUEST_TEMPLATE.md).

Keep public API changes additive and non-breaking where possible; breaking changes need a clear major-version plan and README/CHANGELOG callouts.

### PR description style

**Hard requirement**: use the [PR template](.github/PULL_REQUEST_TEMPLATE.md)'s actual
section headings verbatim — `What kind of change does this PR introduce?`, `What is the
current behavior?`, `What is the new behavior (if this is a feature change)?`, `Does this
PR introduce a breaking change?`, `Recommendations for testing`, `Links to relevant
issues/docs`, and the `Checklist before submitting` with its exact four items. Do not
substitute a different structure (e.g. a generic "Description" / "Type of change" layout)
even for small or maintainer-authored PRs like release/version-bump PRs — every PR must
be created from the template file's own headings.

Fill out the [PR template](.github/PULL_REQUEST_TEMPLATE.md), but keep each section tight:

- State what changed and why. Don't narrate your own editing process or explain why one obvious, in-scope edit was made alongside another (e.g. "also updated X because it references Y") — that's a given fact of the PR, not something a reviewer needs spelled out.
- Don't repeat file paths in prose; the diff already shows them.
- Answer yes/no questions with a plain yes/no; add a sentence only when the answer is non-obvious. "Does this introduce a breaking change?" is the exception: answer "No" alone when it's not, but when it is, give a short explanation of what breaks and for whom.
- Keep "Recommendations for testing" to what a reviewer needs to act on: what ran, what didn't and why, and what to check on CI — one or two sentences, not a full incident writeup.

### PR checklist

- [ ] Project builds for the changed package(s)
- [ ] This PR only changes one package (or documents why an exception is needed)
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` in the changed package, following the [Flutter changelog style](https://github.com/flutter/flutter/blob/master/docs/ecosystem/contributing/README.md#changelog-style) — no version heading until maintainers cut a release
- [ ] Public API documented with `///` doc comments where applicable
- [ ] Rebased onto `develop`
- [ ] New tests added where applicable; all tests pass
- [ ] `dart format .` and `flutter analyze` pass with no errors, no warnings left unfixed
- [ ] Relevant README / docs updated for user-facing changes
- [ ] Full [PR template](.github/PULL_REQUEST_TEMPLATE.md) filled in

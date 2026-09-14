@AGENTS.md

## Claude Code

Everything tool-neutral lives in `AGENTS.md` (imported above). Keep it that way: only add
things here that are specific to Claude Code, and put any new project rule in `AGENTS.md`
so other agents and human contributors pick it up too.

### Tooling in this checkout

- Always drive Flutter/Dart through FVM: `fvm flutter ...` / `fvm dart ...`. A bare
  `flutter` may resolve to a different SDK than CI (`.fvmrc` pins the `stable` channel).
- `flutter run` for `flutter_cache_manager/example/` is long-running — ask before starting
  it and don't leave it running in the background.

### Working style

- Prefer the file tools (Read / Edit / Grep / Glob) over `cat`/`sed`/`grep` in Bash for
  reading and editing repo files.
- Use the `Explore` subagent for wide searches across both packages; the tree is small
  enough that targeted `Grep` is usually faster for anything narrower.
- Run `/code-review` on the diff before handing work over, and `/security-review` when a
  change touches download/HTTP (`lib/src/web/`) or on-disk persistence
  (`lib/src/storage/`).

### Commits and PRs

- Follow the forking + PR workflow in `AGENTS.md`; don't push to
  `Baseflow/flutter_cache_manager` branches directly unless the maintainer asks for it in
  that session.
- End commit messages with:

  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

- End PR descriptions with:

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

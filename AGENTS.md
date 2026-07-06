# fnox-export

Mise environment plugin for selective, batched fnox profile export.

## Release rules

- Patch bump by default for every change.
- Never ship a minor or major bump unless the operator explicitly approves that bump in the current task.
- Tags must be lightweight tags. Do not create annotated tags; mise plugin fetch can fail on annotated tag objects.
- Consumer examples should use the published plugin URL without a fixed `#v...` ref unless the operator explicitly asks for a pin.

## Source of truth

- This repository is canonical. Do not treat the dotfiles/chezmoi checkout as the implementation source.
- Keep local/private secret names and workspace-specific examples out of this repository — this is a public repo, so out of the **git history** too, not just the current tree (`mise run secrets-scan-all` scans all commits). Put private material in dotfiles skills or local docs instead.

## Tooling

Dev tooling is pinned in `mise.toml` (`fnox`, `gitleaks`, `lefthook`). Set up once:

```sh
mise install            # fnox, gitleaks, lefthook at pinned versions
mise run hooks-install  # install lefthook git hooks
```

Tasks: `mise run test` (suite), `mise run secrets-scan` (staged), `mise run
secrets-scan-all` (full history), `mise run check` (scan + test).

## Git hooks

lefthook gates git operations and delegates to the mise tasks above (one source
of truth — do not duplicate raw commands in `lefthook.yml`):

- **pre-commit**: staged gitleaks scan + test suite.
- **pre-push**: full-history gitleaks scan.

Never bypass with `--no-verify`. The secret scan enforces the "keep secrets out"
rule above; fix a finding, do not skip it.

## Testing

- Tests assert observable behavior (output, spawned commands, exit status),
  never plugin source text.
- The suite MUST stay hermetic and re-runnable. `test/run.sh` sandboxes `HOME`
  and the `MISE_*` dirs and sets `FNOX_EXPORT_DAEMON=off` so real fnox daemons
  (whose sockets live in `TMPDIR`, outside the sandbox) are never spawned and
  cannot leak across runs. A test that needs the daemon flag stubs `fnox` (see
  `test/13-daemon.sh`) — never force a real daemon in the suite.

## Verification

Run before release:

```sh
mise run check   # gitleaks full-history scan + test suite
```

`mise run test` (or `bash test/run.sh`) runs the suite alone.

# fnox-export

A [mise](https://mise.jdx.dev/) environment plugin that batch-exports
[`fnox`](https://fnox.jdx.dev/) secrets into mise environment variables with a
flat `from`-based grammar — allow-listed exports, multi-profile merges,
name mappings, and prefix transforms, all driven from your `mise.toml`.

## Features

- **One fnox process, not N.** Runs a single batched `fnox export --format json`
  per profile and filters locally, instead of N serial `fnox get` calls.
- **Daemon-cached by default.** Forces fnox's per-user daemon on
  (`FNOX_DAEMON=on`). Once the daemon is warmed for a profile, resolutions that
  miss mise's env cache — a new shell, an expired TTL, an offsite `cd` — are
  served from the daemon's memory (~0.1s) instead of re-hitting the provider
  (seconds each). The first warm-up still resolves live. Opt out with
  `daemon = false`.
- **Allow-listed exports.** Export only the keys you name, with `*` wildcards.
- **Name mappings and transforms.** `from`/`to` renames, `prefix`,
  `strip_prefix`, and `replace_prefix` rewrites.
- **Multi-profile merges** with explicit `last`/`first`/`error` conflict modes.
- **CI-safe.** `FNOX_EXPORT_DISABLE=1` short-circuits every fnox subprocess.
- **Warm `cd` pays nothing.** The work runs inside mise's environment
  computation, so it is covered by mise's `env_cache` / `env_cache_ttl`.

## Why

Resolving N secrets through N separate `fnox get` calls is N serial provider
round trips and gives the plugin a different failure surface from fnox's batch
export path. With a remote provider, this can dominate directory-activation
time. A single `fnox export --format json` collapses that to one round trip,
and forcing the fnox daemon means repeated and offsite resolutions never re-hit
the provider at all.

The plugin is generic: secret names, provider names, profile choices, selectors,
and mappings all live in the consuming project's `mise.toml`.

## Compared to `jdx/mise-env-fnox`

[`jdx/mise-env-fnox`](https://github.com/jdx/mise-env-fnox) is the simpler
baseline: it loads a single fnox profile directly into mise. Reach for
`fnox-export` when you need more than that.

| Capability | `mise-env-fnox` | `fnox-export` |
|:--|:--:|:--:|
| Load a profile into mise | yes | yes |
| Allow-listed key export (`*` globs) | — | yes |
| `from`/`to` name mappings | — | yes |
| Prefix transforms (`prefix`/`strip_prefix`/`replace_prefix`) | — | yes |
| Multi-profile merge with conflict modes | — | yes |
| Forces fnox daemon for cache hits | — | yes (default) |
| Per-entry / global missing-key policy | — | yes |
| CI disable switch | — | yes |

## Install

Declare the plugin in `mise.toml`:

```toml
[plugins]
fnox-export = "https://github.com/victor-software-house/fnox-export.git"
```

Or install it manually:

```sh
mise plugins install fnox-export https://github.com/victor-software-house/fnox-export.git
```

For development on the plugin itself:

```sh
mise plugin link fnox-export /path/to/fnox-export
```

## Usage

```toml
[settings]
env_cache = true
env_cache_ttl = "4h"

[env]
_.fnox-export = {
  tools = true,
  profiles = ["app"],
  on_missing = "silent",  # default
  on_failure = "warn",    # default
  export = [
    { from = "SERVICE_*", prefix = "SERVICE_" },
    { from = "INFRA_*", prefix = "SERVICE_" },
    { from = "SESSION_JWT", to = "SERVICE_SESSION_JWT" },
    { from = "DATABASE_PASSWORD", to = "SERVICE_DATABASE_PASSWORD" },
    { from = "SCM_PAT", to = "SCM_TOKEN" },
    { from = "DOCS_PAT", to = "DOCS_TOKEN" },
  ],
}
```

- `tools = true` is recommended so the `fnox` binary is on `PATH` when the hook
  runs.
- `env_cache = true` makes the batched export pay off: the computed env is
  cached until a watched file changes or the TTL expires.

## Parameters

| Param | Type | Default | Meaning |
|:--|:--|:--|:--|
| `tools` | bool | `false` | Interpreted by mise: include tool bin paths before the hook runs. |
| `profiles` | array of strings | unset | Primary profile selector. |
| `profile` | string | unset | Alias for `profiles = [profile]`; error if both are set. |
| `export` | string or array | unset | Output spec. Strings are `{ from = "KEY" }` shorthand; tables are flat `from` entries. |
| `on_missing` | enum | `silent` | Missing source behavior: `silent`, `warn`, or `error`. Per-entry override supported. |
| `on_failure` | enum | `warn` | Batch `fnox export` / parse failure behavior: `silent`, `warn`, or `error`. |
| `config` | string | unset | Explicit fnox config path; maps to `fnox -c <path>`. Bypasses global/project discovery. |
| `no_defaults` | bool | `true` when profiles/profile set | Maps to fnox `--no-defaults`; prevents top-level secrets from merging into profile export. |
| `keep_mapped` | bool | `false` | If false, mapped/transformed source keys are not also emitted unchanged. |
| `on_conflict` | enum | `last` | Profile source-key conflict mode: `last`, `first`, `error`. |
| `fnox_bin` | string | `fnox` | Binary/path override. |
| `daemon` | bool | `true` | Prepend `FNOX_DAEMON=on` to the `fnox export` call so resolution uses fnox's per-user daemon cache. Set `false` to stop forcing it and let fnox decide from its own config/environment. Overridden by `FNOX_EXPORT_DAEMON`. |
| `unsafe_default_all` | bool | `false` | Required for unbounded default-profile export with no profile/config. |

## Environment controls

These process-level environment variables override plugin behavior.
`FNOX_EXPORT_DISABLE` is checked first — before any option parsing or
validation — so it works even when the config is invalid or incomplete. The
others override their corresponding option during normal parsing:

| Variable | Values | Meaning |
|:--|:--|:--|
| `FNOX_EXPORT_DISABLE` | truthy value | Skip all fnox subprocesses, option validation, and return an empty, cacheable env. Checked first — before any other processing. Use this in CI or remote contexts where fnox is intentionally unavailable. |
| `FNOX_EXPORT_ON_FAILURE` | `silent`, `warn`, `error` | Override every `on_failure` option. |
| `FNOX_EXPORT_ON_MISSING` | `silent`, `warn`, `error` | Override every global/per-entry `on_missing` option. |
| `FNOX_EXPORT_DAEMON` | truthy/falsy | Override the `daemon` option: truthy prepends `FNOX_DAEMON=on`, falsy omits it (fnox then decides from its own config/environment). |

Truthy values are anything except empty string, `0`, `false`, `no`, or `off`.

### CI usage

Set `FNOX_EXPORT_DISABLE=1` in the GitHub Actions job environment to suppress
all fnox warnings in CI where fnox is not installed:

```yaml
jobs:
  verify:
    runs-on: pretty-little-runner
    env:
      FNOX_EXPORT_DISABLE: "1"
```

The env var is inherited by every step in the job, including those that call
`mise install`, `mise run verify`, `bun install`, and `changesets/action`.

## Export entry grammar

Every table entry uses `from` as the source key or pattern. Strings are
shorthand for `{ from = "KEY" }`.

### 1. Pass-through selector

```toml
export = [
  "SESSION_JWT",
  "SERVICE_*",
  "*",
]
```

A selector exports matching source keys unchanged. Supports `*` wildcards.
Bare `"*"` exports all profile keys and succeeds even when the profile is empty.

### 2. Map to another env var

```toml
export = [
  { from = "SCM_PAT", to = "SCM_TOKEN" },
  { from = "DOCS_PAT", to = "DOCS_TOKEN" },
]
```

`from` is the source fnox key. `to` is the final env var name and must match
`[A-Z_][A-Z0-9_]*`.

### 3. Transform

```toml
export = [
  { from = "SERVICE_*", prefix = "SERVICE_" },
  { from = "LEGACY_*", replace_prefix = ["LEGACY_", "MODERN_"] },
  { from = "DATA_*", prefix = "APP_" },
]
```

Transform fields:

| Field | Meaning |
|:--|:--|
| `from` | Required source selector for table entries. Exact or glob. |
| `strip_prefix` | Remove this prefix from the output env var name. |
| `replace_prefix` | Two-item array: `[old, new]`. Replace old prefix with new prefix. |
| `prefix` | Add this prefix to the output env var name after other transforms. |

`to` is mutually exclusive with transform actions.

### 4. Per-entry `on_missing`

```toml
export = [
  { from = "CRITICAL_TOKEN", on_missing = "error" },
  { from = "OPTIONAL_TOKEN", on_missing = "silent" },
  { from = "DEBUG_*", prefix = "APP_", on_missing = "warn" },
]
```

Per-entry `on_missing` overrides the global `on_missing`.

## Missing keys and failures

### `on_missing`

Controls what happens when an export entry matches nothing.

| Value | Behavior |
|:--|:--|
| `silent` | Skip. No output. Default. |
| `warn` | Skip and emit `log.warn(...)`. |
| `error` | Hard fail via `error(...)`. |

Applies to missing exact selectors, missing mapped sources, and transforms that
match no keys. Bare `"*"` always succeeds.

### `on_failure`

Controls batch `fnox export` / JSON parse failures.

| Value | Behavior |
|:--|:--|
| `warn` | Emit `log.warn(...)` and return an empty/partial env. Default. |
| `error` | Hard fail via `error(...)`. |
| `silent` | Return an empty/partial env silently. |

Warnings show key/profile names only. Secret values are never logged.

## Batch export

Runs one `fnox export --format json` per profile, then filters and maps locally.
This is the only fetch path. fnox does not expose a key-filtered `export`, and
repeated `fnox get KEY` calls have different failure semantics from batch
export.

## Profile semantics

### Single profile

```toml
_.fnox-export = {
  tools = true,
  profiles = ["app"],
}
```

With `profiles` and no `export`, export all scoped keys from the profile.

### Multiple profiles

```toml
_.fnox-export = {
  tools = true,
  profiles = ["base", "app"],
  export = ["*"],
}
```

Profiles are exported in order, source keys are merged, then `export` entries are
applied.

Conflict modes (`on_conflict`):

| Mode | Meaning |
|:--|:--|
| `last` | Later profile wins. Default. |
| `first` | First profile wins. |
| `error` | Duplicate source key across profiles is an error. |

### Repeatable exports

Use repeated `[[env]]` blocks when profiles need independent selectors or
mappings:

```toml
[[env]]
_.fnox-export = {
  tools = true,
  profiles = ["app"],
  export = [
    { from = "INFRA_*", prefix = "SERVICE_" },
    { from = "SCM_PAT", to = "SCM_TOKEN" },
  ],
}

[[env]]
_.fnox-export = {
  tools = true,
  profiles = ["ci"],
  export = [
    { from = "SCM_PAT", to = "CI_SCM_TOKEN" },
  ],
}
```

Later `[[env]]` blocks that emit the same env var overwrite earlier ones.

## Caching and invalidation

The hook returns `cacheable = true` with `watch_files` covering
`fnox config-files` output plus conventional `fnox.toml`, `fnox.local.toml`,
`fnox.<profile>.toml`, and `fnox.<profile>.local.toml`. mise also watches the
plugin directory. The cached env is invalidated when any watched file changes,
the mise config changes, or `env_cache_ttl` expires.

Secret values are returned with `redact = true`, so mise redacts them in its own
output unless the user explicitly opts out.

## Development

Tooling is pinned in `mise.toml` (`fnox`, `gitleaks`, `lefthook`). Install it
and wire the git hooks once:

```sh
mise install          # fnox, gitleaks, lefthook at pinned versions
mise run hooks-install # install lefthook pre-commit / pre-push hooks
```

### Tasks

| Task | What it does |
|:--|:--|
| `mise run test` | Run the integration suite (`test/run.sh`). |
| `mise run secrets-scan` | gitleaks scan of the staged diff (pre-commit gate). |
| `mise run secrets-scan-all` | gitleaks scan of the full git history. |
| `mise run check` | `secrets-scan-all` + `test`. |
| `mise run hooks-install` | Install the lefthook git hooks. |

### Git hooks

`lefthook.yml` delegates to the tasks above, so hooks and manual runs share one
definition:

- **pre-commit** — `secrets-scan` (staged) and `test` (on `*.lua`/`*.sh`/`*.toml`).
- **pre-push** — `secrets-scan-all` (full history).

### Tests

```sh
mise run test   # or: bash test/run.sh
```

The suite is fully isolated: it sandboxes `HOME` and the `MISE_*` dirs and uses
only non-secret `default` values, so it never reads the real global fnox catalog
or mise config.

## License

MIT

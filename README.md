# fnox-export

A [mise](https://mise.jdx.dev/) environment plugin that exports
[`fnox`](https://fnox.jdx.dev/) secrets into mise environment variables with a
flat `from`-based grammar.

The plugin performs one batched `fnox export --format json` per profile and
filters locally.

## Why

Resolving N secrets through N separate `fnox get` calls is N serial provider
round trips and gives the plugin a different failure surface from fnox's batch
export path. With a remote provider, this can dominate directory-activation time. A single
`fnox export --format json` collapses that to one round trip. Because the work
happens inside mise's environment computation, it is covered by mise's
`env_cache` / `env_cache_ttl`, so a warm `cd` pays nothing.

The plugin is generic: secret names, provider names, profile choices, selectors,
and mappings all live in the consuming project's `mise.toml`.

If you only need to load a single fnox profile directly into mise, start with
[jdx/mise-env-fnox](https://github.com/jdx/mise-env-fnox). It is the simpler
baseline plugin. `fnox-export` is for allow-listed exports, multiple profile
merges, and name-mapping workflows.

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
| `unsafe_default_all` | bool | `false` | Required for unbounded default-profile export with no profile/config. |

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

## Test

```sh
bash test/run.sh
```

The test is fully isolated: it sandboxes `HOME` and the `MISE_*` dirs and uses
only non-secret `default` values, so it never reads the real global fnox catalog
or mise config.

## License

MIT

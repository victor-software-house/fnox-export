echo "=== 15: named keys ==="

# `fnox export KEY...` resolves only the named secrets. Each profile below has a
# secret behind a `pass` stub that logs every call and fails, so a call that
# reaches it proves fnox resolved a secret the config did not export.
NAMED_BIN="$SANDBOX/15-bin"
mkdir -p "$NAMED_BIN"
cat > "$NAMED_BIN/pass" <<'STUB'
#!/usr/bin/env bash
echo "pass $*" >> "$PASS_STUB_LOG"
echo "stub provider failure" >&2
exit 1
STUB
chmod +x "$NAMED_BIN/pass"
NAMED_OLD_PATH="$PATH"
export PATH="$NAMED_BIN:$PATH"

named_case() { # name, fnox_content, export_block -> sets P and PASS_STUB_LOG
    P="$SANDBOX/15-$1"
    setup_project "$P" "$2"
    export PASS_STUB_LOG="$P/provider-calls.log"
    printf '[env]\n_.fnox-export = {\n  fnox_bin = "%s",\n%s\n}\n' "$FNOX_BIN" "$3" > "$P/mise.toml"
    trust_project "$P"
}

provider_calls() { # echoes the number of stub provider calls so far
    if [[ -s "$PASS_STUB_LOG" ]]; then wc -l < "$PASS_STUB_LOG" | tr -d ' '; else echo 0; fi
}

named_case exact "$NAMED_FNOX" '  profiles = ["named"],
  export = ["ALPHA_TOKEN", "BETA_TOKEN"],'
check "15.1 exact names export the named keys" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" && "$(getval "$P" BETA_TOKEN)" == "beta-value" ]] && echo 1 || echo 0)"
check "15.2 exact names skip a non-exported secret's provider" "$([[ "$(provider_calls)" == "0" ]] && echo 1 || echo 0)"

named_case wildcard "$NAMED_FNOX" '  profiles = ["named"],
  export = ["ALPHA_TOKEN", "SERVICE_*"],'
check "15.3 a wildcard entry still exports exact and matched keys" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" && "$(getval "$P" SERVICE_FOO)" == "service-foo" ]] && echo 1 || echo 0)"
check "15.4 a wildcard entry resolves the whole profile" "$([[ "$(provider_calls)" != "0" ]] && echo 1 || echo 0)"

named_case star "$NAMED_FNOX" '  profiles = ["named"],
  export = ["*"],'
check "15.5 star exports every resolvable key" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "1" && "$(has_key "$P" SERVICE_FOO)" == "1" ]] && echo 1 || echo 0)"
check "15.6 star resolves the whole profile" "$([[ "$(provider_calls)" != "0" ]] && echo 1 || echo 0)"

named_case all "$NAMED_FNOX" '  profiles = ["named"],'
check "15.7 no export list exports every resolvable key" "$([[ "$(has_key "$P" BETA_TOKEN)" == "1" ]] && echo 1 || echo 0)"
check "15.8 no export list resolves the whole profile" "$([[ "$(provider_calls)" != "0" ]] && echo 1 || echo 0)"

named_case absent-silent "$NAMED_FNOX" '  profiles = ["named"],
  export = ["ALPHA_TOKEN", "NO_SUCH_KEY"],'
expect_success "15.9 a name in no profile is silent by default" "$P"
check "15.10 a name in no profile leaves the other exact key exported" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"
check "15.11 a name in no profile does not resolve the other secrets" "$([[ "$(provider_calls)" == "0" ]] && echo 1 || echo 0)"

named_case absent-warn "$NAMED_FNOX" '  profiles = ["named"],
  on_missing = "warn",
  export = ["NO_SUCH_KEY"],'
expect_warn "15.12 a name in no profile warns under on_missing=warn" "$P" "NO_SUCH_KEY"

named_case absent-error "$NAMED_FNOX" '  profiles = ["named"],
  on_missing = "error",
  export = ["ALPHA_TOKEN", "NO_SUCH_KEY"],'
expect_fail "15.13 a name in no profile fails under on_missing=error" "$P"

named_case only-absent "$NAMED_FNOX" '  profiles = ["named"],
  export = ["NO_SUCH_KEY"],'
expect_success "15.14 only absent names succeed" "$P"
check "15.15 only absent names never export the whole profile" "$([[ "$(provider_calls)" == "0" ]] && echo 1 || echo 0)"

named_case multi "$NAMED_MULTI_FNOX" '  profiles = ["left", "right"],
  export = ["LEFT_ONLY", "RIGHT_ONLY", "SHARED_KEY"],'
check "15.16 a name missing from one profile is exported from the other" "$([[ "$(getval "$P" LEFT_ONLY)" == "left-value" && "$(getval "$P" RIGHT_ONLY)" == "right-value" && "$(getval "$P" SHARED_KEY)" == "left-shared" ]] && echo 1 || echo 0)"
check "15.17 multi-profile exact names skip the other secrets' providers" "$([[ "$(provider_calls)" == "0" ]] && echo 1 || echo 0)"

named_case multi-error "$NAMED_MULTI_FNOX" '  profiles = ["left", "right"],
  on_missing = "error",
  export = ["LEFT_ONLY", "NO_SUCH_KEY"],'
expect_fail "15.18 a name in no profile fails a multi-profile list under on_missing=error" "$P"

named_case mapping "$NAMED_FNOX" '  profiles = ["named"],
  export = [
    { from = "ALPHA_TOKEN", to = "MAPPED_ALPHA" },
    { from = "BETA_TOKEN", to = "MAPPED_BETA" },
  ],'
check "15.19 exact mappings export the targets" "$([[ "$(getval "$P" MAPPED_ALPHA)" == "alpha-value" && "$(getval "$P" MAPPED_BETA)" == "beta-value" ]] && echo 1 || echo 0)"
check "15.20 exact mappings drop the sources" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"
check "15.21 exact mappings skip a non-exported secret's provider" "$([[ "$(provider_calls)" == "0" ]] && echo 1 || echo 0)"

named_case transform "$NAMED_FNOX" '  profiles = ["named"],
  export = [
    { from = "SERVICE_FOO", strip_prefix = "SERVICE_" },
    { from = "BETA_TOKEN", prefix = "X_" },
  ],'
check "15.22 exact transforms export the renamed keys" "$([[ "$(getval "$P" FOO)" == "service-foo" && "$(getval "$P" X_BETA_TOKEN)" == "beta-value" ]] && echo 1 || echo 0)"
check "15.23 exact transforms skip a non-exported secret's provider" "$([[ "$(provider_calls)" == "0" ]] && echo 1 || echo 0)"

# A stub fnox shows the spawned commands: `list` names two keys, and every
# export call is appended to a log.
make_named_stub() { # dir, list_exit
    local dir="$1"
    mkdir -p "$dir/bin"
    printf '%s\n' "$2" > "$dir/list-exit"
    cat > "$dir/bin/fnox" <<'STUB'
#!/usr/bin/env bash
dir="$(cd "$(dirname "$0")/.." && pwd)"
for arg in "$@"; do
    if [ "$arg" = "list" ]; then
        printf ' Key  Type\n ALPHA_TOKEN  default value\n BETA_TOKEN  default value\n'
        exit "$(cat "$dir/list-exit")"
    fi
    if [ "$arg" = "export" ]; then
        printf '%s\n' "$*" >> "$dir/export-calls"
        printf '{"secrets":{"ALPHA_TOKEN":"alpha-value"}}\n'
        exit 0
    fi
done
exit 0
STUB
    chmod +x "$dir/bin/fnox"
}

P="$SANDBOX/15-stub-keys"
setup_project "$P"
make_named_stub "$P" 0
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$P/bin/fnox",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN", "GHOST"],
}
TOML
trust_project "$P"
mise_env_stdout "$P" >/dev/null
export_call="$(head -n 1 "$P/export-calls" 2>/dev/null || true)"
check "15.24 the export call names the defined key" "$([[ "$export_call" == *"export --format json ALPHA_TOKEN" ]] && echo 1 || echo 0)"
check "15.25 the export call omits the undefined key" "$([[ "$export_call" != *GHOST* && "$export_call" != *BETA_TOKEN* ]] && echo 1 || echo 0)"

P="$SANDBOX/15-stub-list-fails"
setup_project "$P"
make_named_stub "$P" 1
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$P/bin/fnox",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
expect_warn "15.26 a failed key listing warns under the default on_failure" "$P" "fnox export failed"
check "15.27 a failed key listing runs no export" "$([[ ! -e "$P/export-calls" ]] && echo 1 || echo 0)"

export PATH="$NAMED_OLD_PATH"
unset PASS_STUB_LOG

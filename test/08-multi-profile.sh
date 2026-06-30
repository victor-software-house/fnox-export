echo "=== 08: multi-profile ==="

P="$SANDBOX/08-last"
setup_project "$P" "$MULTI_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["base", "overlay"],
  export = ["SHARED_KEY"],
  on_conflict = "last",
}
TOML
trust_project "$P"
check "08.1 on_conflict=last uses later profile" "$([[ "$(getval "$P" SHARED_KEY)" == "overlay-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/08-first"
setup_project "$P" "$MULTI_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["base", "overlay"],
  export = ["SHARED_KEY"],
  on_conflict = "first",
}
TOML
trust_project "$P"
check "08.2 on_conflict=first keeps earlier profile" "$([[ "$(getval "$P" SHARED_KEY)" == "base-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/08-error"
setup_project "$P" "$MULTI_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["base", "overlay"],
  export = ["SHARED_KEY"],
  on_conflict = "error",
}
TOML
trust_project "$P"
expect_fail "08.3 on_conflict=error fails on duplicate source" "$P"

P="$SANDBOX/08-non-overlap"
setup_project "$P" "$MULTI_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["base", "overlay"],
  export = ["ONLY_BASE", "ONLY_OVER"],
}
TOML
trust_project "$P"
check "08.4 multi-profile exports ONLY_BASE" "$([[ "$(getval "$P" ONLY_BASE)" == "base-only" ]] && echo 1 || echo 0)"
check "08.5 multi-profile exports ONLY_OVER" "$([[ "$(getval "$P" ONLY_OVER)" == "overlay-only" ]] && echo 1 || echo 0)"

P="$SANDBOX/08-star-all-profiles"
setup_project "$P" "$MULTI_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["base", "overlay"],
  export = ["*"],
}
TOML
trust_project "$P"
check "08.6 star exports base-only key" "$(has_key "$P" ONLY_BASE)"
check "08.7 star exports overlay-only key" "$(has_key "$P" ONLY_OVER)"
check "08.8 star uses last conflict default" "$([[ "$(getval "$P" SHARED_KEY)" == "overlay-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/08-three-profiles"
setup_project "$P" "$THREE_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["first", "second", "third"],
  export = ["SHARED_KEY", "ONLY_FIRST", "ONLY_SECOND", "ONLY_THIRD"],
}
TOML
trust_project "$P"
check "08.9 three profiles: last conflict wins" "$([[ "$(getval "$P" SHARED_KEY)" == "third-value" ]] && echo 1 || echo 0)"
check "08.10 three profiles: first-only present" "$(has_key "$P" ONLY_FIRST)"
check "08.11 three profiles: second-only present" "$(has_key "$P" ONLY_SECOND)"
check "08.12 three profiles: third-only present" "$(has_key "$P" ONLY_THIRD)"

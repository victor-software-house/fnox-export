echo "=== 07: mapped-source behavior ==="

P="$SANDBOX/07-drop-mapped"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    "*",
    { from = "ALPHA_TOKEN", to = "MAPPED" },
  ],
}
TOML
trust_project "$P"
check "07.1 mapped target exported" "$([[ "$(getval "$P" MAPPED)" == "alpha-value" ]] && echo 1 || echo 0)"
check "07.2 mapped source dropped from star" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"
check "07.3 unmapped source still exported from star" "$(has_key "$P" BETA_TOKEN)"

P="$SANDBOX/07-keep-mapped"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  keep_mapped = true,
  export = [
    "*",
    { from = "ALPHA_TOKEN", to = "MAPPED" },
  ],
}
TOML
trust_project "$P"
check "07.4 keep_mapped exports mapped target" "$(has_key "$P" MAPPED)"
check "07.5 keep_mapped keeps source" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/07-transform-maps-source"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    "*",
    { from = "SERVICE_*", strip_prefix = "SERVICE_" },
  ],
}
TOML
trust_project "$P"
check "07.6 transform target exported" "$([[ "$(getval "$P" FOO)" == "service-foo" ]] && echo 1 || echo 0)"
check "07.7 transform source dropped from star" "$([[ "$(has_key "$P" SERVICE_FOO)" == "0" ]] && echo 1 || echo 0)"
check "07.8 unrelated star key remains" "$(has_key "$P" ALPHA_TOKEN)"

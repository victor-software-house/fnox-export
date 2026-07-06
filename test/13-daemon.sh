echo "=== 13: daemon force (FNOX_DAEMON) ==="

# Stub fnox that records the FNOX_DAEMON value it was invoked with, then emits
# a valid export payload so the plugin proceeds normally. Asserts the plugin's
# real spawned-command behavior, not its source text.
make_daemon_stub() { # dir
    local dir="$1"
    local bin="$dir/bin"
    mkdir -p "$bin"
    cat > "$bin/fnox" <<STUB
#!/usr/bin/env bash
# Record the daemon env for the export call; ignore config-files probe.
for arg in "\$@"; do
    if [ "\$arg" = "export" ]; then
        printf '%s' "\${FNOX_DAEMON:-<unset>}" > "$dir/daemon-seen"
        printf '{"secrets":{"ALPHA_TOKEN":"alpha-value"}}\n'
        exit 0
    fi
done
# config-files probe or anything else: succeed quietly.
exit 0
STUB
    chmod +x "$bin/fnox"
    echo "$bin/fnox"
}

# 13.1 default: FNOX_DAEMON=on is forced when neither option nor env is set.
P="$SANDBOX/13-default"
setup_project "$P"
STUB_BIN="$(make_daemon_stub "$P")"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$STUB_BIN",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
# Unset the harness-wide FNOX_EXPORT_DAEMON so this exercises the true default.
( cd "$P" && env -u FNOX_EXPORT_DAEMON mise env -s bash ) >/dev/null 2>&1
if [ "$(cat "$P/daemon-seen" 2>/dev/null)" = "on" ]; then
    check "13.1 daemon forced on by default" 1
else
    check "13.1 daemon forced on by default" 0
fi

# 13.2 opt-out via option: daemon = false omits FNOX_DAEMON entirely.
P="$SANDBOX/13-opt-off"
setup_project "$P"
STUB_BIN="$(make_daemon_stub "$P")"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$STUB_BIN",
  profiles = ["demo"],
  daemon = false,
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
# Unset the harness-wide env override so this exercises the option alone.
( cd "$P" && env -u FNOX_EXPORT_DAEMON mise env -s bash ) >/dev/null 2>&1
if [ "$(cat "$P/daemon-seen" 2>/dev/null)" = "<unset>" ]; then
    check "13.2 daemon = false omits FNOX_DAEMON" 1
else
    check "13.2 daemon = false omits FNOX_DAEMON" 0
fi

# 13.3 env override wins: FNOX_EXPORT_DAEMON=off beats the on-by-default.
P="$SANDBOX/13-env-off"
setup_project "$P"
STUB_BIN="$(make_daemon_stub "$P")"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$STUB_BIN",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
( cd "$P" && FNOX_EXPORT_DAEMON=off mise env -s bash ) >/dev/null 2>&1
if [ "$(cat "$P/daemon-seen" 2>/dev/null)" = "<unset>" ]; then
    check "13.3 FNOX_EXPORT_DAEMON=off overrides default" 1
else
    check "13.3 FNOX_EXPORT_DAEMON=off overrides default" 0
fi

# 13.4 env override wins the other way: FNOX_EXPORT_DAEMON=on beats daemon=false.
P="$SANDBOX/13-env-on"
setup_project "$P"
STUB_BIN="$(make_daemon_stub "$P")"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$STUB_BIN",
  profiles = ["demo"],
  daemon = false,
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
( cd "$P" && FNOX_EXPORT_DAEMON=on mise env -s bash ) >/dev/null 2>&1
if [ "$(cat "$P/daemon-seen" 2>/dev/null)" = "on" ]; then
    check "13.4 FNOX_EXPORT_DAEMON=on overrides daemon=false" 1
else
    check "13.4 FNOX_EXPORT_DAEMON=on overrides daemon=false" 0
fi

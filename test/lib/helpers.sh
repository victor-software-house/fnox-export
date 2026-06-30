check() { # name, condition ("1" pass, anything else fail)
    if [[ "$2" == "1" ]]; then
        printf '  PASS  %s\n' "$1"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  %s\n' "$1"
        FAIL=$((FAIL + 1))
    fi
}

setup_project() { # dir, [fnox_content]
    local dir="$1"
    local fnx="${2:-$DEMO_FNOX}"
    mkdir -p "$dir"
    printf '%s\n' "$fnx" > "$dir/fnox.toml"
}

trust_project() { # dir
    mise trust "$1" >/dev/null 2>&1 || true
}

mise_env_stdout() { # dir
    ( cd "$1" && mise env -s bash ) 2>/dev/null
}

mise_env_capture() { # dir, stdout_file, stderr_file
    ( cd "$1" && mise env -s bash ) >"$2" 2>"$3"
}

getval() { # dir, key
    mise_env_stdout "$1" | sed -n "s/^export $2=//p" | sed "s/^'//; s/'$//" | awk 'END { print }'
}

has_key() { # dir, key -> echoes 1/0
    if mise_env_stdout "$1" | grep -q "^export $2="; then
        echo 1
    else
        echo 0
    fi
}

expect_fail() { # name, dir
    if ( cd "$2" && mise env -s bash ) >/dev/null 2>&1; then
        check "$1" 0
    else
        check "$1" 1
    fi
}

expect_success() { # name, dir
    if ( cd "$2" && mise env -s bash ) >/dev/null 2>&1; then
        check "$1" 1
    else
        check "$1" 0
    fi
}

expect_warn() { # name, dir, pattern
    local out="$SANDBOX/warn-out.$$"
    local err="$SANDBOX/warn-err.$$"
    if mise_env_capture "$2" "$out" "$err" && grep -q "$3" "$err"; then
        check "$1" 1
    else
        check "$1" 0
    fi
    rm -f "$out" "$err"
}

expect_no_warn() { # name, dir, pattern
    local out="$SANDBOX/no-warn-out.$$"
    local err="$SANDBOX/no-warn-err.$$"
    if mise_env_capture "$2" "$out" "$err" && ! grep -q "$3" "$err"; then
        check "$1" 1
    else
        check "$1" 0
    fi
    rm -f "$out" "$err"
}

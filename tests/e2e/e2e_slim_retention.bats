#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════
# E2E-011: slim_reports retention behavior
# ═══════════════════════════════════════════════════════════════
# Verifies slim_yaml.py keeps unprocessed reports for active cmds,
# archives old reports for done cmds, and preserves canonical reports.
# ═══════════════════════════════════════════════════════════════

# bats file_tags=e2e

load "../test_helper/bats-support/load"
load "../test_helper/bats-assert/load"

setup_file() {
    resolve_project_root() {
        local c d abs git_root
        local -a candidates

        candidates=(
            "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
            "$BATS_TEST_DIRNAME"
            "$(dirname "$BATS_TEST_FILENAME")"
            "$BATS_TEST_FILENAME"
            "$PWD"
        )

        for c in "${candidates[@]}"; do
            [ -z "$c" ] && continue

            if [ -f "$c" ]; then
                c="$(dirname "$c")"
            fi

            for d in "$c" "$c/../.." "$c/../../.."; do
                if [ ! -d "$d" ] && [ -d "$PWD/$d" ]; then
                    d="$PWD/$d"
                fi

                abs="$(cd "$d" 2>/dev/null && pwd || true)"
                if [ -n "$abs" ] && [ -f "$abs/scripts/slim_yaml.py" ]; then
                    printf '%s\n' "$abs"
                    return 0
                fi
            done
        done

        git_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$git_root" ] && [ -f "$git_root/scripts/slim_yaml.py" ]; then
            printf '%s\n' "$git_root"
            return 0
        fi

        return 1
    }

    PROJECT_ROOT="$(resolve_project_root)" || skip "Unable to locate project root for slim retention test"
    export PROJECT_ROOT
    [ -f "$PROJECT_ROOT/scripts/slim_yaml.py" ] || skip "slim_yaml.py not found at $PROJECT_ROOT"
    command -v python3 &>/dev/null || skip "python3 not available"
}

build_tmp_project() {
    local root="$1"
    mkdir -p "$root/scripts" "$root/queue"/{inbox,tasks,reports,archive,reports,archive/reports}
}

run_slim_yaml() {
    local root="$1"
    local agent="$2"
    python3 "$root/scripts/slim_yaml.py" "$agent"
}

seed_yaml() {
    local file="$1" value="$2"
    printf '%s\n' "$value" > "$file"
}

@test "E2E-011-A: unprocessed report with active cmd is kept" {
    local root
    root="$(mktemp -d "/tmp/e2e_slim_retention_XXXXXX")"
    build_tmp_project "$root"
    cp "$PROJECT_ROOT/scripts/slim_yaml.py" "$root/scripts/"

    seed_yaml "$root/queue/shogun_to_karo.yaml" $'commands:\n  - id: cmd_test\n    status: pending\n'
    seed_yaml "$root/queue/reports/ashigaru1_cmd_test_report.yaml" $'parent_cmd: cmd_test\nstatus: done\n'
    seed_yaml "$root/queue/reports/ashigaru1_report.yaml" $'parent_cmd: cmd_ignored\nstatus: done\n'

    touch -d "2 days ago" "$root/queue/reports/ashigaru1_cmd_test_report.yaml"
    touch -d "2 days ago" "$root/queue/reports/ashigaru1_report.yaml"

    run run_slim_yaml "$root" karo
    assert_success

    # Active parent_cmd means this report is kept.
    [ -f "$root/queue/reports/ashigaru1_cmd_test_report.yaml" ]
    # Canonical report is always preserved.
    [ -f "$root/queue/reports/ashigaru1_report.yaml" ]

    rm -rf "$root"
}

@test "E2E-011-B: old report for done cmd is archived" {
    local root
    root="$(mktemp -d "/tmp/e2e_slim_retention_XXXXXX")"
    build_tmp_project "$root"
    cp "$PROJECT_ROOT/scripts/slim_yaml.py" "$root/scripts/"

    seed_yaml "$root/queue/shogun_to_karo.yaml" $'commands:\n  - id: cmd_test\n    status: done\n'
    seed_yaml "$root/queue/reports/ashigaru1_cmd_test_report.yaml" $'parent_cmd: cmd_test\nstatus: done\n'
    seed_yaml "$root/queue/reports/ashigaru1_report.yaml" $'parent_cmd: cmd_ignored\nstatus: done\n'

    touch -d "2 days ago" "$root/queue/reports/ashigaru1_cmd_test_report.yaml"
    touch -d "2 days ago" "$root/queue/reports/ashigaru1_report.yaml"

    run run_slim_yaml "$root" karo
    assert_success

    # Non-canonical report is archived.
    [ ! -f "$root/queue/reports/ashigaru1_cmd_test_report.yaml" ]
    [ -f "$root/queue/archive/reports/ashigaru1_cmd_test_report.yaml" ]
    # Canonical report remains.
    [ -f "$root/queue/reports/ashigaru1_report.yaml" ]

    rm -rf "$root"
}

@test "E2E-011-C: canonical report remains even if old and complete" {
    local root
    root="$(mktemp -d "/tmp/e2e_slim_retention_XXXXXX")"
    build_tmp_project "$root"
    cp "$PROJECT_ROOT/scripts/slim_yaml.py" "$root/scripts/"

    seed_yaml "$root/queue/shogun_to_karo.yaml" $'commands:\n  - id: cmd_test\n    status: done\n'
    seed_yaml "$root/queue/reports/ashigaru1_report.yaml" $'parent_cmd: cmd_done\nstatus: done\n'
    touch -d "2 days ago" "$root/queue/reports/ashigaru1_report.yaml"

    run run_slim_yaml "$root" karo
    assert_success

    # Canonical report is always retained.
    [ -f "$root/queue/reports/ashigaru1_report.yaml" ]

    rm -rf "$root"
}

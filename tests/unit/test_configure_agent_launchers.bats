#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "configure agent launchers: Unix wrappers are valid shell and call canonical script" {
  run bash -n "$PROJECT_ROOT/Configure-Agents.sh"
  [ "$status" -eq 0 ]

  run bash -n "$PROJECT_ROOT/Configure-Agents.command"
  [ "$status" -eq 0 ]

  run grep -F "python3 scripts/configure_agents.py" "$PROJECT_ROOT/Configure-Agents.sh"
  [ "$status" -eq 0 ]

  run grep -F "python3 scripts/configure_agents.py" "$PROJECT_ROOT/Configure-Agents.command"
  [ "$status" -eq 0 ]
}

@test "configure agent launchers: Windows wrapper runs canonical script through Ubuntu WSL" {
  run grep -F "wsl.exe -d Ubuntu" "$PROJECT_ROOT/Configure-Agents.bat"
  [ "$status" -eq 0 ]

  run grep -F "wslpath -a" "$PROJECT_ROOT/Configure-Agents.bat"
  [ "$status" -eq 0 ]

  run grep -F "python3 scripts/configure_agents.py" "$PROJECT_ROOT/Configure-Agents.bat"
  [ "$status" -eq 0 ]
}

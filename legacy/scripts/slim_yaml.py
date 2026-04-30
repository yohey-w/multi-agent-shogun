#!/usr/bin/env python3
"""
YAML Slimming Utility

Removes completed/archived items from YAML queue files to maintain performance.
- For Karo: Archives completed task/report files and finished command queue entries.
- For all agents: Archives read: true messages from inbox files.
"""

import os
import sys
import time
from datetime import datetime
from pathlib import Path

import yaml

CANONICAL_TASKS = {f'ashigaru{i}' for i in range(1, 9)} | {'gunshi'}
CANONICAL_REPORTS = {f'ashigaru{i}_report' for i in range(1, 9)} | {'gunshi_report'}
IDLE_STUB = {'task': {'status': 'idle'}}


def load_yaml(filepath):
    """Safely load YAML file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing {filepath}: {e}", file=sys.stderr)
        return {}


def save_yaml(filepath, data):
    """Safely save YAML file."""
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
        return True
    except Exception as e:
        print(f"Error writing {filepath}: {e}", file=sys.stderr)
        return False


def get_timestamp():
    """Generate archive filename timestamp."""
    return datetime.now().strftime('%Y%m%d%H%M%S')


def get_queue_dir():
    return Path(__file__).resolve().parent.parent / 'queue'


def get_active_cmd_ids():
    """Return command IDs in shogun_to_karo that are not done."""
    queue_dir = get_queue_dir()
    shogun_file = queue_dir / 'shogun_to_karo.yaml'
    data = load_yaml(shogun_file)

    key = 'commands' if 'commands' in data else 'queue'
    commands = data.get(key, []) if isinstance(data, dict) else []
    if not isinstance(commands, list):
        return set()

    active = set()
    for cmd in commands:
        if not isinstance(cmd, dict):
            continue
        if cmd.get('id') is None:
            continue
        if cmd.get('status') == 'done':
            continue
        active.add(cmd.get('id'))
    return active


def ensure_parent_dir(path):
    path.parent.mkdir(parents=True, exist_ok=True)


def archive_taskspec(filepath, archive_path, data, dry_run=False):
    if dry_run:
        print(f"[DRY-RUN] would archive: {filepath}")
        print(f"[DRY-RUN] would write: {archive_path}")
        return True

    ensure_parent_dir(archive_path)
    if not save_yaml(archive_path, data):
        return False

    if filepath.name in archive_path.name:
        return True
    return filepath.rename(archive_path)


def slim_tasks(dry_run=False):
    queue_dir = get_queue_dir()
    tasks_dir = queue_dir / 'tasks'
    archive_dir = queue_dir / 'archive' / 'tasks'

    if not tasks_dir.exists():
        return True

    timestamp = get_timestamp()
    done_statuses = {'done', 'completed', 'cancelled'}

    for filepath in sorted(tasks_dir.glob('*.yaml')):
        data = load_yaml(filepath)
        if not isinstance(data, dict):
            continue

        task = data.get('task', {}) if isinstance(data.get('task', {}), dict) else {}
        status = task.get('status', '') if isinstance(task, dict) else ''
        if not status:
            continue

        stem = filepath.stem
        if stem in CANONICAL_TASKS:
            if status not in done_statuses:
                continue

            archive_path = archive_dir / f'{stem}_{timestamp}.yaml'
            if not archive_taskspec(filepath, archive_path, data, dry_run=dry_run):
                return False

            if dry_run:
                print(f"[DRY-RUN] would overwrite: {filepath} with {IDLE_STUB}")
                continue

            if not save_yaml(filepath, IDLE_STUB):
                return False
            continue

        if status not in {'done', 'cancelled'}:
            continue

        archive_path = archive_dir / filepath.name
        if archive_path.exists():
            archive_path = archive_dir / f'{filepath.stem}_{timestamp}{filepath.suffix}'

        if dry_run:
            print(f"[DRY-RUN] would archive: {filepath}")
            print(f"[DRY-RUN] would move to: {archive_path}")
            continue

        ensure_parent_dir(archive_path)
        filepath.rename(archive_path)

    return True


def slim_reports(dry_run=False):
    queue_dir = get_queue_dir()
    reports_dir = queue_dir / 'reports'
    archive_dir = queue_dir / 'archive' / 'reports'

    if not reports_dir.exists():
        return True

    active_cmd_ids = get_active_cmd_ids()
    timestamp = get_timestamp()

    for filepath in sorted(reports_dir.glob('*.yaml')):
        if filepath.stem in CANONICAL_REPORTS:
            continue

        data = load_yaml(filepath)
        parent_cmd = data.get('parent_cmd') if isinstance(data, dict) else None
        is_active = parent_cmd in active_cmd_ids
        is_stale = (time.time() - filepath.stat().st_mtime) >= 86400

        if not is_stale:
            continue
        if is_active:
            continue

        archive_path = archive_dir / filepath.name
        if archive_path.exists():
            archive_path = archive_dir / f'{filepath.stem}_{timestamp}{filepath.suffix}'

        if dry_run:
            print(f"[DRY-RUN] would archive: {filepath}")
            print(f"[DRY-RUN] would move to: {archive_path}")
            continue

        ensure_parent_dir(archive_path)
        filepath.rename(archive_path)

    return True


def slim_inbox(agent_id, dry_run=False):
    """Archive read: true messages from inbox file."""
    queue_dir = get_queue_dir()
    archive_dir = queue_dir / 'archive'
    inbox_file = queue_dir / 'inbox' / f'{agent_id}.yaml'

    if not inbox_file.exists():
        # Inbox doesn't exist yet - that's fine
        return True

    data = load_yaml(inbox_file)
    if not data or 'messages' not in data:
        return True

    messages = data.get('messages', [])
    if not isinstance(messages, list):
        print("Error: messages is not a list", file=sys.stderr)
        return False

    # Separate unread and archived messages
    unread = []
    archived = []

    for msg in messages:
        is_read = msg.get('read', False)
        if is_read:
            archived.append(msg)
        else:
            unread.append(msg)

    # If nothing to archive, return success without writing
    if not archived:
        return True

    archive_timestamp = get_timestamp()
    archive_file = archive_dir / f'inbox_{agent_id}_{archive_timestamp}.yaml'

    if dry_run:
        print(f"[DRY-RUN] would archive: {inbox_file}")
        print(f"[DRY-RUN] would move to: {archive_file}")
        return True

    # Write archived messages to timestamped file
    archive_data = {'messages': archived}
    if not save_yaml(archive_file, archive_data):
        return False

    # Update main file with unread messages only
    data['messages'] = unread
    if not save_yaml(inbox_file, data):
        print(f"Error: Failed to update {inbox_file}, but archive was created", file=sys.stderr)
        return False

    if archived:
        print(f"Archived {len(archived)} messages from {agent_id} to {archive_file.name}", file=sys.stderr)
    return True


def slim_shugun_to_karo():
    """Archive done/cancelled commands from shogun_to_karo.yaml."""
    queue_dir = get_queue_dir()
    archive_dir = queue_dir / 'archive'
    shogun_file = queue_dir / 'shogun_to_karo.yaml'

    if not shogun_file.exists():
        print(f"Warning: {shogun_file} not found", file=sys.stderr)
        return True

    data = load_yaml(shogun_file)
    # Support both 'commands' and 'queue' keys for backwards compatibility
    key = 'commands' if isinstance(data, dict) and 'commands' in data else 'queue'
    if not data or key not in data:
        return True

    queue = data.get(key, [])
    if not isinstance(queue, list):
        print("Error: queue is not a list", file=sys.stderr)
        return False

    # Separate active and archived commands
    active = []
    archived = []

    for cmd in queue:
        status = cmd.get('status', 'unknown')
        if status in ['done', 'cancelled']:
            archived.append(cmd)
        else:
            active.append(cmd)

    # If nothing to archive, return success without writing
    if not archived:
        return True

    # Write archived commands to timestamped file
    archive_timestamp = get_timestamp()
    archive_file = archive_dir / f'shogun_to_karo_{archive_timestamp}.yaml'

    archive_data = {key: archived}
    if not save_yaml(archive_file, archive_data):
        return False

    # Update main file with active commands only
    data[key] = active
    if not save_yaml(shogun_file, data):
        print(f"Error: Failed to update {shogun_file}, but archive was created", file=sys.stderr)
        return False

    print(f"Archived {len(archived)} commands to {archive_file.name}", file=sys.stderr)
    return True


def slim_all_inboxes(dry_run=False):
    queue_dir = get_queue_dir()
    inbox_dir = queue_dir / 'inbox'
    if not inbox_dir.exists():
        return True

    for filepath in sorted(inbox_dir.glob('*.yaml')):
        agent_id = filepath.stem
        if dry_run:
            print(f"[DRY-RUN] processing inbox file: {filepath}")
        if not slim_inbox(agent_id, dry_run=dry_run):
            return False
        if dry_run:
            print(f"[DRY-RUN] finished inbox file: {filepath}")

    return True


def migration(dry_run=False):
    queue_dir = get_queue_dir()
    legacy_archive_dir = queue_dir / 'reports' / 'archive'
    if not legacy_archive_dir.exists():
        return True

    target_dir = queue_dir / 'archive' / 'reports'
    candidates = sorted(legacy_archive_dir.glob('*.yaml'))
    if not candidates:
        if not dry_run:
            legacy_archive_dir.rmdir()
        return True

    if dry_run:
        print(f"[DRY-RUN] would migrate: {len(candidates)} files")
        return True

    target_dir.mkdir(parents=True, exist_ok=True)
    for path in candidates:
        dest = target_dir / path.name
        path.rename(dest)

    if not any(legacy_archive_dir.iterdir()):
        legacy_archive_dir.rmdir()

    return True


def parse_arguments():
    args = [arg for arg in sys.argv[1:] if arg != '--dry-run']
    dry_run = '--dry-run' in sys.argv[1:]
    if len(args) < 1:
        print("Usage: slim_yaml.py <agent_id> [--dry-run]", file=sys.stderr)
        sys.exit(1)

    return args[0], dry_run


def main():
    """Main entry point."""
    agent_id, dry_run = parse_arguments()

    # Ensure archive directory exists
    archive_dir = get_queue_dir() / 'archive'
    archive_dir.mkdir(parents=True, exist_ok=True)

    # Process shogun_to_karo if this is Karo
    if agent_id == 'karo':
        if not slim_shugun_to_karo():
            sys.exit(1)
        migration(dry_run)
        if not slim_tasks(dry_run):
            sys.exit(1)
        if not slim_reports(dry_run):
            sys.exit(1)
        if not slim_all_inboxes(dry_run):
            sys.exit(1)

    # Process inbox for all agents
    if not slim_inbox(agent_id, dry_run):
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import json
import os
import subprocess
from datetime import date, timedelta
from pathlib import Path

def get_git_stats():
    # Resolve target repository: prefer cool-shell or current dir
    repo_dir = Path.home() / ".config/quickshell/cool-shell"
    if not (repo_dir / ".git").exists():
        repo_dir = Path.cwd()

    def run(cmd):
        try:
            return subprocess.check_output(cmd, cwd=str(repo_dir), text=True, stderr=subprocess.DEVNULL).strip()
        except Exception:
            return ""

    branch = run(["git", "branch", "--show-current"]) or "main"
    repo_name = run(["git", "rev-parse", "--show-toplevel"])
    repo_name = Path(repo_name).name if repo_name else "cool-shell"
    last_commit = run(["git", "log", "-1", "--format=%cr (%h)"]) or "No recent commits"

    today = date.today()
    days = [(today - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]
    log_raw = run(["git", "log", "--since=7 days ago", "--date=short", "--format=%ad"])
    log_dates = log_raw.splitlines() if log_raw else []

    day_items = []
    total_commits = 0
    for d in days:
        c = log_dates.count(d)
        total_commits += c
        dt = date.fromisoformat(d)
        day_items.append({
            "date": d,
            "dayName": dt.strftime("%a"),
            "commits": c
        })

    return {
        "repo": repo_name,
        "branch": branch,
        "lastCommit": last_commit,
        "totalCommits": total_commits,
        "days": day_items
    }

if __name__ == "__main__":
    print(json.dumps(get_git_stats()))

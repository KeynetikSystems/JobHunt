"""Project root + .env loader. Stdlib only — no python-dotenv dependency."""
import os
from pathlib import Path

ROOT = Path(__file__).parent
ENV_FILE = ROOT / ".env"


def load_env() -> dict:
    """Reads .env (KEY=VALUE per line) merged with real environment variables.
    A real environment variable always wins over the .env file, so Task
    Scheduler or a shell override still works without editing the file."""
    env = dict(os.environ)
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            if key not in os.environ:
                env[key] = value.strip().strip('"').strip("'")
    return env


def save_env(updates: dict) -> None:
    """Rewrites .env with the given key/value updates, preserving comments and
    unrelated lines in place. Keys not already present are appended."""
    lines = ENV_FILE.read_text(encoding="utf-8").splitlines() if ENV_FILE.exists() else []
    remaining = dict(updates)
    out = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            key = stripped.split("=", 1)[0].strip()
            if key in remaining:
                out.append(f"{key}={remaining.pop(key)}")
                continue
        out.append(line)
    for key, value in remaining.items():
        out.append(f"{key}={value}")
    ENV_FILE.write_text("\n".join(out) + "\n", encoding="utf-8")

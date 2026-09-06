import pathlib
import re
import subprocess

tracked = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
failures = []
for name in filter(None, tracked):
    path = pathlib.Path(name)
    if any(part in {".build", "build", "vault", "node_modules", "__pycache__"} for part in path.parts):
        failures.append((name, "generated or private directory"))
    if path.name.startswith("._") or path.suffix.lower() in {".p12", ".pfx", ".key", ".pem", ".dmg", ".zip"}:
        failures.append((name, "private key or release artifact"))
    if path.name == ".env" or path.name.startswith(".env."):
        failures.append((name, "environment file"))
    if path.suffix in {".swift", ".sh", ".md", ".yml", ".yaml", ".plist"}:
        data = path.read_text()
        if re.search(r"/(?:Users|home)/[A-Za-z0-9_.-]+/", data):
            failures.append((name, "personal absolute path"))
for name, reason in failures:
    print(f"{name}: {reason}")
raise SystemExit(bool(failures))

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import sysconfig


def main():
    parser = argparse.ArgumentParser(description="Run the Rivus simulation or regression checks.")
    parser.add_argument("mode", nargs="?", default="demo", choices=["demo", "test", "eval", "intake"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    jac = Path(sysconfig.get_path("scripts")) / ("jac.exe" if os.name == "nt" else "jac")
    if not jac.is_file():
        jac = shutil.which("jac")
    if not jac:
        parser.error("Install requirements.txt in the active Python environment first.")

    for cache in (root / ".jac", root / "jac" / ".jac"):
        if cache.is_symlink() or not cache.resolve().is_relative_to(root):
            parser.error(f"Refusing to clear a cache outside the project: {cache}")
        if cache.is_dir():
            shutil.rmtree(cache)

    entry = {"demo": "main", "test": "test_pipetrace", "eval": "evaluate", "intake": "intake_demo"}[args.mode]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(root)
    return subprocess.call([str(jac), "run", f"jac/{entry}.jac"], cwd=root, env=env)


if __name__ == "__main__":
    raise SystemExit(main())

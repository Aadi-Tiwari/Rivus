import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import run


class LauncherTests(unittest.TestCase):
    def test_uses_active_interpreters_scripts_directory_without_path_lookup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            jac = scripts / ("jac.exe" if os.name == "nt" else "jac")
            jac.touch()
            with patch.object(run, "__file__", str(root / "run.py")), \
                 patch.object(run.sys, "argv", ["run.py", "test"]), \
                 patch.object(run.sysconfig, "get_path", return_value=str(scripts)), \
                 patch.object(run.shutil, "which") as lookup, \
                 patch.object(run.subprocess, "call", return_value=3) as execute:
                self.assertEqual(run.main(), 3)
            lookup.assert_not_called()
            self.assertEqual(execute.call_args.args[0], [str(jac), "run", "jac/test_pipetrace.jac"])
            self.assertEqual(execute.call_args.kwargs["cwd"], root)


if __name__ == "__main__":
    unittest.main()

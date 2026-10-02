import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("compile_examples.sh")


class CompileExamplesTest(unittest.TestCase):
    def test_all_examples_failure_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "example").mkdir()
            (root / "example" / "broken.dart").write_text("void main() {}")
            dart = root / "fake-dart"
            dart.write_text("#!/bin/sh\nexit 7\n")
            dart.chmod(0o755)

            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                env={**os.environ, "DART": str(dart)},
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("compiling broken", result.stdout)

    def test_all_examples_success_returns_zero(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "example").mkdir()
            (root / "example" / "ok.dart").write_text("void main() {}")
            dart = root / "fake-dart"
            dart.write_text("#!/bin/sh\nexit 0\n")
            dart.chmod(0o755)

            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                env={**os.environ, "DART": str(dart)},
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()

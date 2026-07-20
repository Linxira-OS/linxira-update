import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "src/lib/write_status.py"
spec = importlib.util.spec_from_file_location("write_status", MODULE_PATH)
write_status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(write_status)


class StatusTests(unittest.TestCase):
    def test_reboot_required_tracks_running_kernel_image(self):
        with mock.patch.object(Path, "is_file", return_value=True):
            self.assertFalse(write_status.reboot_required())
        with mock.patch.object(Path, "is_file", return_value=False):
            self.assertTrue(write_status.reboot_required())

    def test_status_document_is_written_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch("sys.argv", [
                "write_status.py",
                "--state-dir",
                directory,
                "--available-count",
                "4",
            ]), mock.patch.object(write_status, "reboot_required", return_value=False):
                write_status.main()
            document = json.loads((Path(directory) / "status.json").read_text(encoding="utf-8"))
        self.assertEqual(document["version"], 1)
        self.assertEqual(document["available_update_count"], 4)
        self.assertFalse(document["reboot_required"])
        self.assertTrue(document["last_check"].endswith("Z"))


if __name__ == "__main__":
    unittest.main()

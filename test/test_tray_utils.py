import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).parents[1] / "src/lib/tray_utils.py"
spec = importlib.util.spec_from_file_location("tray_utils", MODULE_PATH)
tray_utils = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tray_utils)


class TrayTimerTests(unittest.TestCase):
    def test_formats_timer_duration(self):
        timer_json = '[{"next": 93784000000}]'
        self.assertEqual(
            tray_utils.get_next_check_duration_human_readable(timer_json, now=0),
            "1d 2h 3m 4s",
        )

    def test_rejects_malformed_or_unexpected_timer_json(self):
        for value in ("", "not json", "{}", "[]", '[{"next": "unknown"}]'):
            with self.subTest(value=value):
                self.assertIsNone(
                    tray_utils.get_next_check_duration_human_readable(value, now=0)
                )

    def test_expired_timer_is_due_now(self):
        self.assertEqual(
            tray_utils.get_next_check_duration_human_readable('[{"next": 1}]', now=1),
            "now",
        )

    def test_cosmic_prefers_cosmic_term_with_exec(self):
        candidates = tray_utils.terminal_candidates("COSMIC")
        self.assertEqual(candidates[0], ("/usr/bin/cosmic-term", ("-e",)))
        self.assertEqual(len(candidates), 4)

    def test_cosmic_launcher_uses_shell_fallback_for_110(self):
        source = (Path(__file__).parents[1] / "src/lib/tray.py").read_text(encoding="utf-8")
        self.assertIn('"SHELL=/usr/bin/linxira-update"', source)
        self.assertIn('terminal, "--no-daemon"', source)

    def test_kde_prefers_konsole(self):
        candidates = tray_utils.terminal_candidates("KDE")
        self.assertEqual(candidates[0], ("/usr/bin/konsole", ("--hold", "-e")))


if __name__ == "__main__":
    unittest.main()

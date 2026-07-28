from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


class AboutMetadataTests(unittest.TestCase):
    def test_appstream_identity_and_maintenance_urls(self):
        root = ET.parse(ROOT / "res/org.linxira.Update.metainfo.xml").getroot()
        self.assertEqual(root.findtext("id"), "org.linxira.Update")
        urls = {item.attrib.get("type"): item.text for item in root.findall("url")}
        self.assertEqual(urls["vcs-browser"], "https://github.com/Linxira-OS/linxira-update")
        self.assertEqual(urls["bugtracker"], "https://github.com/Linxira-OS/linxira-update/issues")
        self.assertEqual(urls["help"], "https://linxira-os.github.io/linxira-wiki/")

    def test_tray_exposes_about_action(self):
        source = (ROOT / "src/lib/tray.py").read_text(encoding="utf-8")
        self.assertIn('self.menu_about = QAction(_("About Linxira Update"))', source)
        self.assertIn("self.menu_about.triggered.connect(self.about)", source)
        self.assertIn('check_status = "unknown"', source)
        self.assertIn("self.menu_launch.setEnabled(False)", source)
        self.assertIn("if self.check_process.state() != QProcess.ProcessState.NotRunning:", source)


if __name__ == "__main__":
    unittest.main()

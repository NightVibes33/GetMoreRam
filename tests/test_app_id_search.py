"""Regression coverage for Memory navigation after removing automatic app artwork."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONTENT = (ROOT / "GetMoreRam/ContentView.swift").read_text()
DETAIL = (ROOT / "GetMoreRam/AppIDView.swift").read_text()
SETTINGS = (ROOT / "GetMoreRam/SettingsView.swift").read_text()
MODEL = (ROOT / "GetMoreRam/AppIDViewModel.swift").read_text()
SIMULATOR = (ROOT / ".github/workflows/simulator-ui.yml").read_text()

class MemoryFirstTests(unittest.TestCase):
    def test_three_tabs_and_no_app_id_panel(self):
        self.assertNotIn('Label("App IDs"', CONTENT)
        self.assertNotIn('actionTile("App IDs"', CONTENT)
        self.assertNotIn('struct AppIDView : View', DETAIL)
        for title, index in (("Home", 0), ("Memory", 1), ("Settings", 2)):
            self.assertIn('Label("' + title + '"', CONTENT)
            self.assertIn('.tag(' + str(index) + ')', CONTENT)

    def test_memory_capability_and_search(self):
        self.assertIn('Section("Applications")', CONTENT)
        self.assertIn('AppIDEditView(viewModel: app)', CONTENT)
        self.assertIn('localizedStandardContains(q)', CONTENT)
        self.assertIn('AppleAPI.shared.fetchAppIDsForTeam(team: team, session: session)', MODEL)
        self.assertIn('try await viewModel.addIncreasedMemory()', DETAIL)

    def test_remove_automatic_memory_icons_only(self):
        self.assertNotIn('AppIconArtworkStore', CONTENT)
        self.assertNotIn('AppArtworkIconView', CONTENT)
        self.assertNotIn('AppArtworkIconView', DETAIL)
        self.assertNotIn('SideloadIconSourcesView', SETTINGS)
        self.assertFalse((ROOT / "GetMoreRam/AppIconArtworkStore.swift").exists())

    def test_keep_home_screen_icon_switcher(self):
        self.assertIn('IconAppearanceView()', SETTINGS)
        self.assertIn('SelectedAppIcon', SETTINGS)

    def test_simulator_audit_keeps_three_tab_routes(self):
        self.assertIn('names=(Home Memory Settings ClientInfo IconPicker)', SIMULATOR)
        self.assertIn('for i in 0 1 2 3 4; do', SIMULATOR)
        self.assertIn('-eq 5', SIMULATOR)

if __name__ == "__main__":
    unittest.main()

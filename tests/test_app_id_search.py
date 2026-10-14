"""Three-tab navigation and automatic sideload-catalog icon regression coverage."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONTENT = (ROOT / "GetMoreRam/ContentView.swift").read_text()
DETAIL = (ROOT / "GetMoreRam/AppIDView.swift").read_text()
SETTINGS = (ROOT / "GetMoreRam/SettingsView.swift").read_text()
MODEL = (ROOT / "GetMoreRam/AppIDViewModel.swift").read_text()
ARTWORK = (ROOT / "GetMoreRam/AppIconArtworkStore.swift").read_text()
SIMULATOR = (ROOT / ".github/workflows/simulator-ui.yml").read_text()


class MemoryFirstTests(unittest.TestCase):
    def test_only_three_tabs(self):
        self.assertNotIn('Label("App IDs"', CONTENT)
        self.assertNotIn('actionTile("App IDs"', CONTENT)
        self.assertNotIn("struct AppIDView : View", DETAIL)
        for label, index in (("Home", 0), ("Memory", 1), ("Settings", 2)):
            self.assertIn(f'Label("{label}"', CONTENT)
            self.assertIn(f'.tag({index})', CONTENT)

    def test_memory_retains_capability_flow_and_search(self):
        self.assertIn('Section("Applications")', CONTENT)
        self.assertIn('AppIDEditView(viewModel: app)', CONTENT)
        self.assertIn('AppArtworkIconView(bundleID: app.bundleID', CONTENT)
        self.assertIn('localizedStandardContains(q)', CONTENT)
        self.assertIn('AppleAPI.shared.fetchAppIDsForTeam(team: team, session: session)', MODEL)

    def test_no_manual_import_or_installed_app_scans(self):
        self.assertIn('await artwork.refresh(bundleIDs:', CONTENT)
        self.assertIn('AppIconArtworkStore.defaultSources', CONTENT)
        self.assertNotIn('fileImporter', CONTENT)
        self.assertNotIn('fileImporter', DETAIL)
        self.assertNotIn('LSApplicationWorkspace', ARTWORK)
        self.assertNotIn('itunes.apple.com', ARTWORK)
        self.assertNotIn('IPAIconExtractor', ARTWORK)

    def test_real_catalog_matching_and_persistent_cache(self):
        self.assertIn('https://community-apps.sidestore.io/sidecommunity.json', ARTWORK)
        self.assertIn('https://apps.sidestore.io/', ARTWORK)
        self.assertIn('app["bundleIdentifier"]', ARTWORK)
        self.assertIn('app["iconURL"]', ARTWORK)
        self.assertIn('requested.contains(id.lowercased())', ARTWORK)
        self.assertIn('SideloadIconCache', ARTWORK)
        self.assertIn('SideloadIconSourcesView()', SETTINGS)

    def test_updated_simulator_route(self):
        self.assertIn('names=(Home Memory Settings ClientInfo IconPicker)', SIMULATOR)
        self.assertIn('for i in 0 1 2 3 4; do', SIMULATOR)
        self.assertIn('-eq 5', SIMULATOR)


if __name__ == "__main__":
    unittest.main()

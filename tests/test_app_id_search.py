"""Regression coverage for the local App ID search UI.

The search must filter Apple's fetched developer-team App IDs locally. It must
not replace the upstream list with unrelated installed-app discovery.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
VIEW = ROOT / "GetMoreRam" / "AppIDView.swift"
MODEL = ROOT / "GetMoreRam" / "AppIDViewModel.swift"


class AppIDSearchTests(unittest.TestCase):
    def test_explicit_search_button_and_clear(self):
        view = VIEW.read_text()
        self.assertIn('"Search App IDs"', view)
        self.assertIn('systemImage: isSearchPresented ? "xmark" : "magnifyingglass"', view)
        self.assertIn('searchText = ""', view)
        self.assertIn('@FocusState private var isSearchFocused', view)

    def test_search_filters_name_and_bundle_id(self):
        view = VIEW.read_text()
        self.assertIn('app.appID.name.localizedStandardContains(query)', view)
        self.assertIn('app.bundleID.localizedStandardContains(query)', view)
        self.assertIn('ForEach(filteredAppIDs, id: \\.self)', view)
        self.assertIn('guard !query.isEmpty else { return viewModel.appIDs }', view)
        self.assertIn('"No matching App IDs."', view)

    def test_preserves_upstream_apple_team_app_id_source(self):
        model = MODEL.read_text()
        self.assertIn('AppleAPI.shared.fetchAppIDsForTeam(team: team, session: session)', model)
        self.assertNotIn('LSApplicationWorkspace', model)


if __name__ == "__main__":
    unittest.main()

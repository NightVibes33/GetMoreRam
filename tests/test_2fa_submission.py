"""Regression checks for the GetMoreRam SideSign 2FA submit workflow.

The Xcode runner compiles the Swift changes; these targeted source-level checks
also reject the exact legacy-handler guard that silently dropped submission.
"""
import pathlib
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / "GetMoreRam" / "LoginViewModel.swift"
VIEW = pathlib.Path(__file__).resolve().parents[1] / "GetMoreRam" / "SettingsView.swift"


class TwoFactorSubmissionTests(unittest.TestCase):
    def test_side_sign_continuation_is_resumed_without_legacy_handler(self):
        src = SOURCE.read_text()
        func = src.split("func submitVerificationCode()", 1)[1].split("func cancelAuthentication()", 1)[0]
        self.assertNotIn("guard !isVerificationCodeSubmitting,\n              let verificationCodeHandler", func)
        self.assertIn("if let continuation = sideSignContinuation", func)
        self.assertIn("sideSignContinuation = nil", func)
        self.assertIn("continuation.resume(returning: .verificationCode(code))", func)
        self.assertIn("if let handler = verificationCodeHandler", func)

    def test_2fa_retries_reenable_submission(self):
        src = SOURCE.read_text()
        func = src.split("private func requestSideStoreVerification(", 1)[1].split("private func prepareForVerification(", 1)[0]
        self.assertIn("isVerificationCodeSubmitting = false", func)
        self.assertIn("sideSignContinuation = continuation", func)

    def test_submit_button_reports_its_state(self):
        src = VIEW.read_text()
        self.assertIn('"Verifying Code…"', src)
        self.assertIn('"Submit Code"', src)
        self.assertIn("viewModel.submitVerificationCode()", src)


if __name__ == "__main__":
    unittest.main()

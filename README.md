# GetMoreRam

**Manage Apple's Increased Memory Limit capability for a developer App ID directly from an iPhone, without opening Xcode.**

GetMoreRam is an iOS SwiftUI app for browsing the App IDs available to a selected Apple Developer team and requesting the \`INCREASED_MEMORY_LIMIT\` capability. It uses [SideSign](https://github.com/SideStore/SideSign) for Apple authentication, [AnisetteKit](https://github.com/mahee96/AnisetteKit) for on-device Anisette, and [StosSign](https://github.com/stossy11/StosSign) for developer-team and App ID operations.

> [!IMPORTANT]
> **Current Apple authentication compatibility (user-reported): Windows is the only Client Identity preset confirmed working.** Android and macOS presets have been reported to fail against Apple's authentication/developer services; untested Custom headers are not considered working. **Select Windows manually in Settings → Client Identity before signing in.** The app does **not** force Windows and still sends the Client-Info and User-Agent values actually saved in Settings. A successful CI build or anonymous Apple lookup does not prove any preset will authenticate on your Apple account.

## What it does — and does not do

- Lists developer-team App IDs from Apple's services and lets you search by application name or bundle identifier.
- Sends an Apple Developer request to enable \`INCREASED_MEMORY_LIMIT\` for the selected App ID.
- Supports Apple sign-in, two-factor verification and developer-team selection.
- Supports on-device Anisette (default) or a user-configured remote V3 Anisette server.
- Provides editable identity headers, a saved-session flow, SideStore account JSON import, and ten selectable app icons.

**It does not add physical RAM, expose a RAM slider, patch an already-installed IPA, inject entitlements into a running app, sign IPAs, or bypass Apple's developer-account entitlement restrictions.** An App ID capability update and an entitlement embedded in a newly signed app are distinct operations.

## Requirements

- iPhone or iPad with **iOS 18.0 or newer**; the project currently builds against the **iOS 27 SDK**. A successful build is not a guarantee that every iOS version or Apple API route works.
- An Apple account with access to the **developer team and App ID** you intend to change. Apple's account/team eligibility rules determine whether the capability is accepted.
- A way to **sign and install** the unsigned GetMoreRam IPA, such as [SideStore](https://sidestore.io/). For the target app, you also need to generate a new provisioning profile and re-sign it afterward.
- Network access to Apple's authentication/developer services. First-time on-device Anisette setup also needs access to its ODA library metadata/download source.

Current Xcode project version: **1.2 (build 3)**; bundle identifier: \`com.nightvibes33.getmoreram\`. Check the exact installed version under **Settings → Build Information**.

## Install and enable Increased Memory Limit

1. Open **[GitHub Actions → unsigned IPA build](https://github.com/NightVibes33/GetMoreRam/actions/workflows/build.yml)**, choose a successful run for the desired commit, and download the \`GetMoreRam-unsigned-iOS18-27\` artifact. The artifact is a ZIP containing \`GetMoreRam-unsigned-iOS18-27.ipa\`.
2. Sign the IPA with SideStore or your preferred legitimate iOS signing method, then **install that signed IPA**. SideStore's **Refresh** operation on an old installation does **not** import the new GetMoreRam build.
3. In GetMoreRam, open **Settings → Client Identity → Windows**. Confirm that the Client-Info and User-Agent fields show the Windows values. The editable fields are authoritative; merely naming a preset is not a substitute for checking the values. **Windows is recommended based on reported behavior**, not hardcoded into requests.
4. Keep **Settings → On-device Anisette** enabled for local Anisette, or disable it and enter your own working **remote V3 Anisette Server URL** under **Anisette Options**. This provider choice is independent of the Client Identity preset.
5. Open **Settings → Sign in** and authenticate with the Apple account that owns/accesses the target App ID. Complete Apple's 2FA prompts and choose the appropriate developer team. If you already have a SideStore account export, **Settings → Import SideStore Account** supports importing its JSON file, but you still need to sign in.
6. Open the **Memory** tab, refresh the developer application list if needed, and search by name or bundle ID. This lists **Apple Developer App IDs**, not installed apps; there is no separate App IDs tab.
7. Select the intended App ID and tap **Add Increased Memory Limit**. The app requests \`INCREASED_MEMORY_LIMIT\` from Apple's developer API. Do not assume success if the server returns an authentication or permission error.
8. After a successful update, **regenerate/obtain the target app's provisioning profile and re-sign and reinstall or refresh the target app with SideStore** so that the new signature can include the entitlement. Verify that the resulting signed app/profile contains \`com.apple.developer.kernel.increased-memory-limit\` set to \`true\`. Apple's response alone does not confirm the entitlement is in the installed app.

## Client Identity compatibility

GetMoreRam exposes **Settings → Client Identity** with Android, macOS, Windows, and Custom. Choosing a preset fills in both editable fields; further edits are used for subsequent requests. **Changing either field is a real request-header change, not a visual-only label.**

| Identity | Current reported result | Guidance |
| --- | --- | --- |
| **Windows** | **Working in the reported user tests** | **Recommended**; manually select it before authentication. |
| Android (Pixel 7 / Android 14) | Authentication/developer-service requests reported rejected | **Known not working in those tests**; retained for experimentation. |
| macOS | Authentication/developer-service requests reported rejected | **Known not working in those tests**; retained for experimentation. |
| Custom | Not independently verified; values can be rejected | Advanced use only; no guarantee a supplied profile is supported. |

The failures are **consistent with Apple rejecting the affected request profiles**, but the exact server-side cause has **not** been independently established. A \`401\` response may also reflect an expired developer token, inconsistent identity/provisioning headers, or missing account/team authorization. Do not treat changing a User-Agent as a guaranteed fix or assume Apple's behavior will be stable.

**No forced fallback or silent profile substitution:** Windows remains user-selectable, not a global default. If Android/macOS fails, explicitly choose Windows and sign in again. Do **not** expect the app to secretly use Windows while displaying Android or Custom.

### On-device Anisette vs Client Identity

These are two different settings:

- **On-device Anisette (default):** Uses SideSign/AnisetteKit to provision and generate Anisette information locally. First use obtains runtime library metadata from \`https://zzz.haus/oda.json\`; it is **not fully offline**. The current implementation reads any configured \`CustomClientInfo\` and \`CustomUserAgent\` as its provisioning headers; when neither is configured, it has Android defaults. A saved device identifier and \`adi.pb\` provisioning blob are reused where possible.
- **Remote V3 Anisette:** Explicitly disable the on-device toggle to use the configured remote server (default server URL in the code: \`https://ani.sidestore.io\`). There is **no silent remote fallback** after local failure.
- **Client Identity:** The selected/editable Apple Client-Info and User-Agent feed authentication and the patched developer-service request path. Switching the Anisette provider does not itself select Windows.

A locally generated Anisette response proves neither Apple sign-in nor entitlement activation succeeded.

## Troubleshooting

| Symptom | What it means / what to check |
| --- | --- |
| **HTTP 401** when applying Increased Memory Limit | Apple rejected the authenticated Developer API request. Confirm **Windows** is actually selected, sign out and sign back in with that identity, check the selected team/App ID and developer-account privileges, then retry. A successful sign-in alone does not establish permission to edit a capability. |
| **Android or macOS identity cannot connect/sign in** | These modes are currently reported broken against Apple. Switch to **Windows** explicitly. They are not silently mapped to Windows. |
| **HTTP 502, 503, 504**, or HTML rather than Apple data | May be an Apple gateway/server failure. Wait before retrying; these responses do not prove the Anisette provider or your password is wrong. |
| **Invalid response / plist or JSON decoding failure** | An Apple or Anisette endpoint returned an unexpected response. Check the error stage, selected provider and server URL. |
| **Apple error -22411** during authentication | Apple did not issue the required developer-services token. Check account security/verification prompts at [account.apple.com](https://account.apple.com/); receiving a 2FA code does not guarantee the final token stage succeeded. |
| **No App IDs listed** | Verify you're signed in, the correct developer team is selected, and the account has access to App IDs; use the Memory tab's refresh button. |
| **Capability accepted but target app unchanged** | Re-provision and re-sign the **target IPA**, then verify its signed entitlements. GetMoreRam does not modify an already-installed copy. |
| **Existing GetMoreRam still shows old UI** | Import/install the **newly built IPA**. Refreshing an older signed installation does not update its app code. |
| **Anisette provisioning fails** | Check network access to the ODA metadata/runtime source or verify the remote V3 URL, depending on your chosen mode. Don't clear saved provisioning/account state as an initial troubleshooting step. |

**Keychain cleanup is a last resort.** Settings includes a **Clean Up Keychain** action, but it removes locally stored authentication/provisioning state and may require signing in and provisioning again. If necessary, back up your own recovery information first. A SideStore account export can contain sensitive credentials and provisioning data; **never publish it in GitHub issues, Actions logs, or screenshots**.

## Interface

The app has **three tabs**:

- **Home:** Account/team status, overview, and navigation to Memory and Settings.
- **Memory:** Live developer-team App ID list, search, refresh, and the capability request for a selected App ID.
- **Settings:** Account sign-in/import/team selection, on-device or remote Anisette, Client Identity, appearance/theme, icon switcher, installed version, and optional Keychain cleanup.

### Appearance and icons

The primary icon is **Default**. The nine registered alternate icons are **Blue, Purple, Green, Mono, Glass, Orbit, Gradient, Carbon, Board**. These are separate committed 1024 × 1024 PNG iOS asset catalog images with corresponding 256 × 256 previews; they are **not screenshot placeholders**. **Settings → Appearance → App Icon** uses iOS's \`UIApplication.setAlternateIconName\` and updates its selection after the OS confirms the change.

The shipping artwork is in \`GetMoreRam/Assets.xcassets\`. CI validates the committed assets and does not regenerate or replace them. \`scripts/generate_app_icons.swift\` is a historical prototype, **not** a shipping build step.

## Build from source

Clone the repository on a Mac with the compatible Xcode/iOS SDK and open **\`GetMoreRam.xcodeproj\`**, scheme **GetMoreRam**. The Xcode project has an **iOS 18.0 deployment target**. Dependencies are resolved with Swift Package Manager.

The release pipeline applies compatibility/identity adjustments to **temporary SwiftPM dependency checkouts** before compiling, so building directly in Xcode without equivalent patches may not behave exactly like the GitHub Actions release:

- \`scripts/patch_stossign_auth.py\` — legacy authentication compatibility handling;
- \`scripts/patch_stossign_api_response.py\` — developer API response parsing and HTTP diagnostics;
- \`scripts/patch_stossign_identity.py\` — reads current Settings Client-Info/User-Agent in the StosSign developer API;
- \`scripts/patch_sidesign_apple_http.py\` — scoped handling of transient Apple HTTP gateway responses.

To use the same automated build path:

1. Visit **[iOS unsigned IPA workflow](https://github.com/NightVibes33/GetMoreRam/actions/workflows/build.yml)** and choose **Run workflow → main → Run workflow**, or push a commit to \`main\`.
2. The workflow uses the \`xcode-27\` runner with Xcode 27 and the iOS 27 SDK, resolves Swift packages, applies the dependency patches, archives with \`CODE_SIGNING_ALLOWED=NO\`, and verifies the unsigned bundle's ID, minimum OS, and alternate icon registration.
3. Download the **\`GetMoreRam-unsigned-iOS18-27\`** artifact from that run. It contains the unsigned \`.ipa\` and must be signed for installation.

The workflow's Ubuntu job runs the checked-in Python tests and an **unauthenticated** Apple provisioning-lookup probe using a Pixel 7/Android-style request. That probe is **not an Android login test**, does not use credentials, and **must not be interpreted as evidence that the Android identity preset works**. Its external connectivity probe is informational; tests and the Xcode job determine workflow success.

The independent **[iPhone Simulator Screenshot Audit](https://github.com/NightVibes33/GetMoreRam/actions/workflows/simulator-ui.yml)** builds the actual Debug app and captures Home, Memory, Settings, Client Identity, and App Icon picker screens. It does **not** verify live Apple login or capability changes.

**Validation boundaries:** A green Xcode build proves the unsigned binary compiles and packages; it does not prove Apple's current APIs accept the selected identity, a token is valid, or a developer team has entitlement access. The reported Windows-only compatibility is an empirical observation, not a feature guaranteed by CI.

## Project components and credits

- [StosSign](https://github.com/stossy11/StosSign) — Apple Developer App ID and capability APIs.
- [SideSign](https://github.com/SideStore/SideSign) and [SideStore](https://github.com/SideStore/SideStore) — Apple authentication and Anisette architecture.
- [AnisetteKit](https://github.com/mahee96/AnisetteKit) — local Anisette provisioning/runtime.

Refer to each dependency's repository for its own licensing and attribution. **This repository's README does not grant rights to redistribute third-party code beyond its actual license terms.**

## Security and support

Apple account credentials, exported SideStore JSON, saved auth tokens, \`adi.pb\`, and two-factor codes are sensitive. Do not attach them to issue reports. If reporting a problem, provide the **app version/build, iOS version, selected identity preset, Anisette mode, the failing operation, HTTP status/error domain, and sanitized logs**—never the credentials or raw authentication headers.

This is an independent developer utility, not an Apple or SideStore service. Apple can change or reject private Developer API behavior without notice.

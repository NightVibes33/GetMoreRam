# Get More Ram
A simple [StosSign](https://github.com/stossy11/StosSign) wrapper app that allows you to enable "Increased Memory Limit" for your sideloaded apps without using Xcode.

# How to use
1. Install GetMoreRam (sign its unsigned IPA with SideStore first).
2. Open **Settings** and sign in using the **same Apple account and developer team that SideStore uses to sign the target app**.
3. Open **App IDs**, tap **Refresh**, then tap the **magnifying-glass search button** to find your target app by name or bundle identifier. This lists Apple developer-team App IDs, **not necessarily the apps currently installed on your iPhone**.
4. Select the target App ID, then tap **Add Increased Memory Limit** to request `INCREASED_MEMORY_LIMIT` from Apple.
5. **Re-sign and reinstall/refresh the target app in SideStore after enabling the capability.** The previously installed copy retains its old provisioning profile, so enabling the App ID alone does not change the installed app.
6. Check the **newly signed target app**, not GetMoreRam, for the entitlement `com.apple.developer.kernel.increased-memory-limit` set to `true` in its signed entitlements/provisioning profile.

**Important:** This changes the capability associated with the target Apple developer App ID. GetMoreRam does not inject an entitlement into an already-installed app or itself re-sign the target IPA. Apple's acceptance of the update does not guarantee the entitlement is included in a new signature; verify the resulting installation.

# Credits
Stossy11 - For StosSign.
SideStore - Anisette Data fetching codes are stolen from SideStore

## iOS 18–27 compatibility and Android-to-Apple connectivity check

- Bundle ID: `com.nightvibes33.getmoreram`; minimum OS: **iOS 18.0**, compatible through iOS 27 with the same IPA. The upper bound is not hard-coded in the app.
- GitHub Actions uses the `xcode-27` ARM64 macOS runner with Xcode 27 and the iOS 27 SDK. The app's Debug and Release deployment targets are both iOS 18.0; compiling against the newer SDK does not require iOS 27 at runtime.
- The build archives without signing and uploads `GetMoreRam-unsigned-iOS18-27.ipa` as a workflow artifact. Install it by signing it with your own certificate, for example using SideStore.
- A separate job tests Apple's *unauthenticated* provisioning lookup using the Pixel 7 Android 14 `X-MMe-Client-Info` and User-Agent. The job checks for a successful HTTP response containing provisioning URLs. It does **not** authenticate an Apple ID and does not prove sign-in is fixed.
- Trigger the workflow with a push to `main`, or visit **Actions → iOS 18-27 - Xcode 27 - Unsigned IPA and Android Apple Test → Run workflow**.

No Apple ID credentials or anisette secrets are passed to the connectivity test.

## Compatibility verification

The Actions build validates the packaged IPA's `MinimumOSVersion=18.0` and uses Xcode 27 to compile against the current SDK. GetMoreRam retains upstream Apple developer-team App ID discovery, capability enabling, and the SideStore re-signing instructions. Apple authentication and entitlement availability ultimately depend on Apple's servers, your account/team, and SideStore's generated provisioning profile. Builds do not substitute for on-device testing on each iOS version.

## On-device Anisette (ClientQUI v1.0 integration)

- **Enabled by default**, using `AnisetteKit` through `SideSign.AnisetteDataManager`. The first use downloads ODA runtime libraries from the metadata source in ClientQUI v1.0 (`https://zzz.haus/oda.json`), then anisette headers are generated locally on the device and the libraries are cached.
- GetMoreRam still uses **SideSign for Apple login and trusted-device/SMS/voice 2FA**, and **StosSign for developer App ID and Increased Memory Limit APIs**.
- In **Settings → On-device Anisette**, switch the toggle **off** to use the configured remote Anisette V3 server. No automatic remote fallback sends provisioning data when the local ODA path fails.
- Real Apple sign-in and ODA library compatibility on each iOS version still require on-device verification.

## Confirm you installed the new IPA

GetMoreRam **v1.1 (build 2)** adds the On-device Anisette switch and a **Settings → Build Information** section showing the installed app version and Anisette mode. Earlier builds (including v1.0 build 1) do not have these controls.

**Install the newly downloaded IPA using SideStore's IPA import/install process, not just Refresh on the existing app.** Refresh re-signs an already installed app; it does not import new source code. Sign/install this IPA with the same Apple account as before, then open Settings and verify `App Version = 1.1 (2)` and `Anisette Mode = On-device ODA`. Do not use Clean Up Keychain to force an update.

## Icon switcher and built-in icon assets

The nine alternate icon names in the iOS asset catalog are `Blue`, `Purple`, `Green`, `Mono`, `Glass`, `Orbit`, `Gradient`, `Carbon`, and `Board`. The primary `AppIcon` is the Default design. A deterministic macOS Swift renderer generates ten 1024×1024 PNG app icons and matching picker preview assets before Xcode archives the IPA. Icons are styled after the supplied ten-design chip reference; the original higher-resolution individual PNG crops are available separately in the ChatGPT delivery. The build verifies every alternate name appears in the signed-app metadata before distributing the unsigned IPA. The iOS icon picker only marks the choice after `UIApplication.setAlternateIconName` completes without error.

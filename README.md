# Get More Ram
A simple [StosSign](https://github.com/stossy11/StosSign) wrapper app that allows you to enable "Increased Memory Limit" for your sideloaded apps without using Xcode.

# How to use
1. Sideload this app
2. Go to settings, sign in your account that you used to sign the app you want to enable "Increased Memory Limit"
3. Go to "App IDs" page
4. Tap Refresh
5. Tap the app you want to enable "Increased Memory Limit"
6. Tap "Add Increased Memory Limit"
7. Reinstall the app from SideStore/AltStore
8. Check if you have "Increased Memory Limit"

# Credits
Stossy11 - For StosSign.
SideStore - Anisette Data fetching codes are stolen from SideStore

## iOS 27 build and Android-to-Apple connectivity check

- Bundle ID: `com.nightvibes33.getmoreram`; minimum OS: iOS 27.0.
- GitHub Actions uses the `xcode-27` ARM64 macOS runner with Xcode 27 and the iOS 27 SDK.
- The build archives without signing and uploads `GetMoreRam-unsigned-iOS27.ipa` as a workflow artifact. Install it by signing it with your own certificate, for example using SideStore.
- A separate job tests Apple's *unauthenticated* provisioning lookup using the Pixel 7 Android 14 `X-MMe-Client-Info` and User-Agent. The job checks for a successful HTTP response containing provisioning URLs. It does **not** authenticate an Apple ID and does not prove sign-in is fixed.
- Trigger the workflow with a push to `main`, or visit **Actions → iOS 27 - Xcode 27 - Unsigned IPA and Android Apple Test → Run workflow**.

No Apple ID credentials or anisette secrets are passed to the connectivity test.

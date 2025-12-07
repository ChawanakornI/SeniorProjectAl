# Google Sign-In Setup Instructions

Your project has the `google_sign_in` package installed and code implemented, but it is missing the required configuration files and settings for iOS and macOS.

## 1. Download Configuration File
1. Go to the [Firebase Console](https://console.firebase.google.com/) (or Google Cloud Console).
2. Select your project.
3. Go to Project Settings.
4. **For iOS:** Download `GoogleService-Info.plist`.
5. **For macOS:** Download the macOS version of `GoogleService-Info.plist` (often the same as iOS if configured together, but ensure the Bundle ID matches).

## 2. Add Files to Project
You must add these files to your project structure **and** ensure they are included in the Xcode build.

### iOS
1. Drag `GoogleService-Info.plist` into the `ios/Runner` directory.
2. **Important:** You must open `ios/Runner.xcworkspace` in Xcode and add the file to the project navigator (Right click Runner -> Add Files to "Runner").

### macOS
1. Drag `GoogleService-Info.plist` into the `macos/Runner` directory.
2. **Important:** Open `macos/Runner.xcworkspace` in Xcode and add the file to the project navigator.

## 3. Configure URL Schemes
I have added a placeholder structure to your `Info.plist` files. You need to update it with your specific ID.

1. Open `GoogleService-Info.plist` in a text editor.
2. Find the key `REVERSED_CLIENT_ID` (it looks like `com.googleusercontent.apps.123456...`).
3. Copy the value.
4. Open `ios/Runner/Info.plist` and replace `com.googleusercontent.apps.YOUR-CLIENT-ID-HERE` with the copied value.
5. Open `macos/Runner/Info.plist` and replace `com.googleusercontent.apps.YOUR-CLIENT-ID-HERE` with the copied value.

## 4. About the "Run Script" Warning
You may see a warning: `Run script build phase 'Run Script' will be run during every build...`
*   **Severity:** Low (Warning). It does not prevent the app from building.
*   **Cause:** A build script (usually for embedding frameworks) doesn't declare input/output files, so Xcode runs it every time to be safe.
*   **Fix:** This is often fixed automatically by newer Flutter versions or can be silenced in Xcode by unchecking "Based on dependency analysis" for that script phase, or defining the outputs. **You can ignore this warning for now.**

## 5. Run the App
After adding the files and updating the Info.plist, run:
```bash
flutter clean
flutter pub get
flutter run
```

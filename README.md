# OurMoney iOS

Native SwiftUI port of the uploaded OurMoney Android app. The Android source is treated as the behavioral source of truth.

## Parity implemented

- Google/Firebase authentication flow
- Name setup and 6-digit two-person household pairing
- Real-time Firestore sync with pending-write state
- Shared and personal expenses
- EQUAL / EXACT / PERCENTAGE / SHARES split models
- UPI / Cash payment methods
- Edit/delete transactions
- Shared balance and settle-up flow
- Settlement history and editing/deletion
- Transaction history search, smart filters, date-range filters
- PDF report export/share
- Monthly budgets with ALL / SHARED / PERSONAL scopes
- Custom categories
- Budget health, pacing, weekly chart, payment split, two-person responsibility and insights
- Savings goals with contributions/edit/delete
- Analytics and category breakdown
- AI chats with PERSONAL / SHARED scope and Firestore persistence
- Gemini financial-context prompting matching the uploaded Android implementation
- Settings: disconnect and destructive transaction reset
- Dark graphite/slate/teal visual system matching the Android theme
- iPhone-safe-area and native sheet/navigation behavior

## Required Apple/Firebase setup

The uploaded Firebase project currently contains an Android Firebase app only. iOS authentication requires an iOS app registration in the same Firebase project. After registering bundle ID `com.ourmoney.app`, download its `GoogleService-Info.plist` and replace the template in this project.

The Android project also embeds a Gemini API key through build configuration. This port reads `GEMINI_API_KEY` from `Config.xcconfig`/Info.plist for behavioral parity. For a public production App Store build, move Gemini calls behind a server-side endpoint instead of shipping the key in the app.

## Build

This environment is Linux and does not contain Apple's Xcode/iOS SDK, so the IPA itself cannot be compiled or code-signed here. On macOS with Xcode installed:

1. Install XcodeGen: `brew install xcodegen`
2. Replace `OurMoney/GoogleService-Info.plist.template` with the actual Firebase iOS plist named `GoogleService-Info.plist`.
3. Put the Gemini key in `Config/Secrets.xcconfig` based on `Config/Secrets.xcconfig.example`.
4. Run `xcodegen generate`.
5. Open `OurMoney.xcodeproj` in Xcode.
6. Select your Apple development team and a real iOS device.
7. Build/run once to verify Firebase and Google sign-in.
8. Use `Scripts/build_ipa.sh` for an unsigned device IPA, or archive/sign from Xcode for a distributable IPA.

## Important source note

The separate web folder in the uploaded archive is not used as the source of truth because it is a reduced feature set and contains a placeholder web app ID. The native Android app contains more features and is the reference for parity.

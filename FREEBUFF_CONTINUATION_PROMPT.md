# OurMoney iOS — Freebuff Continuation Brief

You are continuing an iOS migration of the Android application **OurMoney**.

## Primary goal
Finish this project as a **real native iOS app** with behavior and data compatibility matching the existing Android OurMoney implementation as closely as iOS permits.

Do NOT create a demo, mockup, prototype, fake buttons, simulated authentication, hard-coded sample users, fake Firebase responses, or placeholder functionality.

Use the supplied project files as the current iOS implementation and improve/fix them in place.

## Android behavior is the source of truth
Preserve the existing Android app's actual behavior, including:

- Two-user account/household pairing with a 6-digit connection code.
- Google authentication flow.
- User name setup.
- Shared and personal transactions.
- Personal transaction privacy: a user's personal records must not be exposed to the other household member.
- Transaction add/edit/delete.
- Categories and custom categories.
- Cash/UPI payment information where present in the model.
- Exact balance/settlement calculations.
- Settlement records, add/edit/delete.
- History search and filters.
- Date-range filtering.
- Budgets with shared/personal/all scopes.
- Budget progress/analytics and spending insights.
- Savings goals and contributions.
- Analytics/category breakdowns.
- PDF financial report generation and native iOS share/export.
- OurMoney AI chat, using real app financial context and persistent chat history where supported by the existing architecture.
- Settings, disconnect/cancel pairing, diagnostics, and destructive transaction reset behavior.
- Real-time Firestore synchronization.

## Critical correctness rules
1. Never replace a real feature with a stub just to make the build pass.
2. Never auto-authenticate a sample user.
3. Never hard-code fake Firebase data.
4. Do not silently change Firestore collection/document/field names unless absolutely required for iOS compatibility and documented.
5. Preserve the existing balance/settlement algorithm exactly. Add regression tests for asymmetric expenses and settlements.
6. Personal transactions must be filtered to the current user's `createdBy`/ownership rules where required by the Android behavior.
7. Do not mix Android-only resources into the iOS target.
8. Avoid duplicate Swift type definitions across files.
9. There must be exactly one production `@main` app entry point.
10. Remove all compiler errors and warnings that are caused by this project code.
11. Do not claim a build succeeded unless the cloud/macOS build actually succeeded.
12. Do not claim an IPA is installable unless it is actually signed/provisioned or clearly identified as unsigned.

## Firebase
The supplied repository may contain a template or placeholder `GoogleService-Info.plist`.

If a real iOS plist is supplied separately, use that exact file. Do not invent Firebase values.

Required iOS bundle identifier:
`com.ourmoney.app`

Keep Firebase Auth and Firestore integration real.

## Google Sign-In
Implement a real iOS Google Sign-In flow compatible with the Firebase project.
Configure the iOS URL scheme/Info.plist entries from the real Firebase plist rather than inventing values.

## Build configuration
Build as a real iOS device application, not Mac Catalyst.

Target:
`OurMoney`

SDK:
`iphoneos`

Configuration:
`Release`

Use the current Xcode version available on the cloud macOS runner.

## Known failure from the previous cloud build
The previous GitHub Actions build failed during archive with:
`Multiple commands produce .../Applications/.app`

The old Xcode project also resolved its product bundle identifier incorrectly as:
`com.example.ourmoney`

Fix the Xcode project so there is exactly one valid application product with the intended bundle identifier:
`com.ourmoney.app`

Explicitly verify PRODUCT_NAME, FULL_PRODUCT_NAME, WRAPPER_EXTENSION, PRODUCT_BUNDLE_IDENTIFIER, and the application output path before archiving.

## Required validation before final delivery
Run all practical checks available in your environment:

- Swift syntax/compile checks.
- Unit tests for ledger/balance calculations.
- Project/scheme validation.
- Firebase configuration presence validation.
- Archive using `xcodebuild archive` for iphoneos.
- Verify the archive contains `Products/Applications/OurMoney.app`.
- Verify the generated `.app` contains a valid `Info.plist` and the expected bundle identifier.
- Package a valid IPA with `Payload/OurMoney.app`.
- If signing credentials are available, produce a signed installable IPA.
- If signing credentials are not available, produce an explicitly unsigned IPA and report that fact rather than pretending it is installable.

## IPA delivery
At the end, create:
`artifacts/OurMoney.ipa`

Also provide a clear build report containing:
- build success/failure
- Xcode version
- iOS SDK version
- bundle identifier
- IPA size
- signed vs unsigned
- test results
- any remaining blocker

## UI requirement
Keep the supplied OurMoney iOS UI and visual language coherent with the Android version. Do not redesign the product unnecessarily. Match screen structure, labels, navigation, states, and interactions before making cosmetic improvements.

## Final instruction
Work directly on the supplied project. Inspect existing code first. Fix the implementation rather than replacing it with a simplified app. Verify every feature you touch. Do not stop after creating a project skeleton. The expected output is a production-quality iOS build artifact, not merely Swift source files.

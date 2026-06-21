# Google Play — release checklist

Status legend: ✅ done in repo · ⏳ needs your input/action · ☐ to do in Play Console

## 1. Code / build
- ⏳ **Application ID** — still `com.example.dendrite` (Play rejects `com.example.*`,
  and the ID is permanent). Pick a real reverse-domain ID, then update:
  `namespace` + `applicationId` in `android/app/build.gradle.kts`, the package in
  `MainActivity.kt`, and move it from `android/app/src/main/kotlin/com/example/dendrite/`.
- ✅ **Release signing** wired in `android/app/build.gradle.kts` — reads
  `android/key.properties`, falls back to debug when absent.
- ⏳ **Create the upload keystore** and `android/key.properties` (see
  `android/key.properties.example`). Back up the `.jks` + passwords; both are
  gitignored.
- ☐ Build the bundle: `flutter build appbundle --release` →
  `build/app/outputs/bundle/release/app-release.aab`.
- ☐ Confirm `targetSdk` meets Play's current minimum (Flutter's default tracks
  it; verify at upload time).

## 2. Play Console account
- ☐ Pay the **$25** one-time registration fee.
- ☐ Personal account: line up **12+ testers** for the mandatory **14-day closed
  test** before you can request production access. (Org account needs a D-U-N-S.)
- ☐ Enroll in **Play App Signing** (recommended) when creating the app.

## 3. Store listing  (copy ready → `STORE_LISTING.md`)
- ✅ EN + zh-CN title / short / full description drafted.
- ☐ App icon 512×512.
- ☐ **Feature graphic 1024×500** (square cover is social-only; needs a wide variant).
- ☐ 2–8 phone screenshots — reuse `submission/site/img/{mindmap,home,settings}.png`.

## 4. App content / policy
- ✅ **Privacy policy** page → `submission/site/privacy.html`, deploys to
  `https://vtechlab-escapor.github.io/Dendrite/showcase/privacy.html`.
- ✅ **Data safety** answers drafted → `DATA_SAFETY.md` (key point: declare that
  conversation content is shared with the user's chosen third-party AI provider).
- ☐ Complete **content rating** questionnaire.
- ☐ **Generative AI policy**: add an in-app way to report/flag offensive AI output
  before review.
- ☐ Target audience & ads declarations (no ads → declare none).

## 5. China / distribution note
Google Play is unavailable in mainland China. Given the bilingual/Xiaohongshu
audience, also consider domestic stores (Huawei AppGallery, Xiaomi GetApps, etc.)
— each has its own signing + review flow, separate from this checklist.

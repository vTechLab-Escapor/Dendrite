# Google Play — Data safety form answers

Fill this in at Play Console → **App content → Data safety**. The nuance for
Dendrite: you run **no backend**, but the app **transmits user-typed content to
the third-party AI provider the user configures** (NVIDIA / OpenAI / Anthropic /
Google / a local model). That transmission must be disclosed even though you
never see or store it. Be honest here — mismatches with observed behavior are a
common rejection/suspension cause.

---

## Top-level

| Question | Answer | Note |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Because conversation content is *sent* to a third-party AI endpoint. |
| Is all collected data encrypted in transit? | **Yes** | Provider calls are HTTPS. (Cleartext is scoped to local-dev IPs only and not used in production.) |
| Do you provide a way for users to request that their data be deleted? | **Yes** | All data is on-device; users delete conversations in-app and uninstalling wipes everything. |

---

## Data types — declare these

### App activity / Other user-generated content — "Messages / other in-app content"
- **Collected?** No (you store it only on the user's device — on-device-only
  storage does NOT count as "collected" under Play's definition).
- **Shared?** **Yes** — sent to the third-party AI provider chosen by the user to
  generate a response.
  - Purpose: **App functionality** (core AI feature).
  - Is sharing optional? It's required to use the AI feature, but the user
    chooses *which* provider (including a fully on-device model that shares
    nothing).
  - Processed ephemerally? Depends on provider; do **not** claim ephemeral on
    their behalf.

### Personal info — API keys / credentials
- The user's **API keys** are stored in the platform secure keystore on-device,
  **not collected or shared** by you. Don't declare these as collected — but the
  privacy policy explains where they live.

### What you do NOT collect (declare "No")
- Location, contacts, photos, identifiers/advertising ID, crash logs/analytics
  (unless you later add a crash/analytics SDK — if you do, revisit this), purchase
  history, financial info.

---

## Practical notes
- If you ever add Firebase Crashlytics, Google Analytics, an ad SDK, or any
  telemetry, you MUST update this form — those collect identifiers/diagnostics.
- The "on-device storage isn't collection" rule is why a local-first app can
  legitimately answer "No" to most rows — but the **third-party AI share is the
  one row you cannot skip**.

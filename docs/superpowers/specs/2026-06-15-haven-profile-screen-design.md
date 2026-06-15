# Haven Profile Screen — Design

**Date:** 2026-06-15
**Status:** Approved (build it)

## Goal

Give the top-right profile icon on the Today screen a real destination: a screen that surfaces and lets the user manage the data Haven already holds about them — their migraine profile (from onboarding), subscription, reminders, weather location, and a data/privacy section.

## Decisions (locked)

- **Migraine-profile rows are editable from day one.** Tapping a row reopens that onboarding question; the new answer persists.
- **Export is a stub:** a share sheet of a plain-text summary of recent days. Real PDF is a later follow-up.
- **No real auth.** Still anonymous `DeviceIdentity.current` (`sim-device` in DEBUG). The header is self-description, not a login.

## Screen structure (sheet presented from the `person` icon)

1. **Header — "Your profile"**
   The computed migraine class from `buildProfile(answers).klass` (e.g. "Episodic migraine with aura"). A muted "Sign in to sync (coming soon)" line as the future hook (non-functional).

2. **Your migraine profile** *(editable)*
   One row per answered onboarding question, in catalog order, showing the question's short title and the selected option label(s). Tapping a row opens a single-question editor (reuses `QuestionScreen`); saving merges the new answer and persists. The sex-gated `cycle` question is hidden when `sex` isn't female/intersex (mirrors onboarding's `requiresSex`).

3. **Subscription**
   Current status ("Haven Premium — active" / "Free"). **Manage** opens the system manage-subscriptions sheet. **Restore Purchases** reuses the existing entitlement check.

4. **Reminders**
   Daily reminder time, editable (segmented morning/afternoon/evening). Saving persists `reminderTime` and reschedules the local notification.

5. **Weather & location**
   Whether barometric risk is active, and the coordinates in use (or "Not set"). A button to (re)grant + capture location via the existing `LocationOnce`.

6. **Data & privacy**
   - **Export report** → share sheet of plain-text recent-day summary (stub).
   - **Delete my data** → confirmation → wipes all day docs + settings → app returns to onboarding.

7. **About**
   Appearance (dark/light theme toggle, persisted via existing `settings:updateSettings`), Terms, Privacy, app version.

## Architecture

Follows the established split. New pure/testable logic goes in `HavenCore`; backend in `convex`; presentation in the app.

### HavenCore (headless, unit-tested)
- **Extend `Settings`** to decode `answers: String`, `reminderTime: String`, `lat: Double?`, `lon: Double?` (backend already returns them; the model currently drops them). Keep existing fields + defaults.
- **`ProfileSummary`** — pure mapping `func profileRows(answers: [String: [String]]) -> [ProfileRow]` where `ProfileRow = (questionId: String, title: String, value: String)`. Uses `OnboardingCatalog.questions` to resolve option `value`→`label`; joins multi-selects with ", "; omits unanswered and the sex-gated `cycle` row when not applicable; uses a short title per question (add `shortTitle` to the catalog rows via a lookup table in `ProfileSummary`, NOT by changing `OnboardingQuestion`).
- **`DoctorReport.text(days: [DayLog], klass: String) -> String`** — plain-text summary: header line with class + date range + attack count, then one line per day that had a migraine or notable foods. Pure, tested.
- **`answersDict(from json: String) -> [String: [String]]`** and **`answersJSON(from dict:) -> String`** helpers (the encode/decode used by both onboarding and profile), tested. (OnboardingFlow currently inlines `JSONSerialization`; refactor it to use these.)
- **Extend `DayDataSource`** with: `updateAnswers(_ json: String) async throws`, `setReminderTime(_ time: String) async throws`, `deleteMyData() async throws`.

### Convex (typechecked, convex-test)
- **`settings:updateAnswers`** `(userId, answers: string)` → patches `answers` (keeps `onboarded` true). Idempotent upsert.
- **`settings:setReminderTime`** `(userId, reminderTime: string)` → patches `reminderTime`.
- **`days:deleteAll`** `(userId)` → deletes every `days` doc for the user.
- **`settings:deleteAccount`** `(userId)` → deletes the settings row (so the app re-gates to onboarding). `deleteMyData()` in the service calls `days:deleteAll` then `settings:deleteAccount`.

### App (SwiftUI)
- **`ConvexService`** implements the three new protocol methods.
- **`ProfileStore`** (`@Observable @MainActor`, in app) — loads `Settings`, exposes `answers` dict + derived `Profile`, and `saveAnswer(questionId:values:)`, `setReminderTime(_:)`, `deleteData()`; delegates to the `DayDataSource`.
- **`ProfileScreen`** — the sectioned UI above, styled with existing `havenText`/theme tokens.
- **`QuestionEditorSheet`** — wraps `QuestionScreen` with a local binding; "Save" (relabel the CTA from "Next") merges + persists, then dismisses.
- **`TopBar`** gains `onProfile: () -> Void`; the `person` button triggers it. `TodayScreen`/`RootTabView` present `ProfileScreen` as a sheet.
- **Delete routing:** `ProfileScreen` takes `onDataDeleted: () -> Void`; `RootView` passes a closure that sets `onboarded = false`, bouncing back to onboarding.
- **Export:** `ShareLink(item: DoctorReport.text(...))`.
- **Manage subscription:** `AppStore.showManageSubscriptions(in:)` (StoreKit 2); fall back to opening the subscriptions URL if unavailable on simulator.

## Error handling
- All writes are `try?`-guarded in the UI with the optimistic local update reverted on failure (match existing sheet patterns).
- Delete requires explicit confirmation (`confirmationDialog`) before wiping.
- Export/manage gracefully no-op if StoreKit/data unavailable.

## Testing
- HavenCore: `profileRows` (single, multi, unanswered, sex-gated hidden), `DoctorReport.text` (range/count/lines), `answersDict`/`answersJSON` round-trip + Settings decoding the new fields.
- Convex: `updateAnswers`, `setReminderTime`, `days:deleteAll`, `settings:deleteAccount` (convex-test).
- Maestro: open profile → edit the "frequency" question → assert the row reflects the new value; open delete confirm and cancel.
- Fidelity: compare against prototype tokens (no profile screen exists in the handoff, so match the app's existing card/section styling).

## Out of scope (follow-ups)
- Real account/auth + cross-device sync.
- Real PDF doctor report.
- Per-field weather location editing beyond re-grant.

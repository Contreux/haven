# Haven — App Store Deployment (v1.0.0)

Launch plan: **free app** (no IAP), **TestFlight first**, then App Store review.

## Status

### ✅ Done in the codebase (branch merged to main)
- **App icon** — `Haven/Sources/Assets.xcassets/AppIcon.appiconset` (flame mark, brand orange on cream). Replace `AppIcon-1024.png` to rebrand later.
- **Version** — `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1`.
- **Encryption compliance** — `ITSAppUsesNonExemptEncryption = NO` in Info.plist (skips the per-build question; true because we only use exempt HTTPS).
- **Backend split** — `ConvexService` uses **prod** (`focused-turtle-754`) in Release builds, **dev** (`cool-anteater-665`) in Debug. Device identity is a persistent per-install UUID in Release (`sim-device` only in Debug).
- **Seed safety** — `convex/seed.ts` refuses to run unless `ALLOW_SEED=true` (set on dev only) or under the test runner. Prod can't be wiped by it.
- **Free launch** — onboarding skips the paywall; `PaywallScreen` + StoreKit code are retained for the v1.1 paid release.

### ⏳ Needs you (account / external)

1. **Team ID** — App Store Connect → Membership → copy the 10-char Team ID and give it to me, OR set it yourself: in `Haven/project.yml` under `settings.base` add
   ```yaml
   DEVELOPMENT_TEAM: ABCDE12345
   CODE_SIGN_STYLE: Automatic
   ```
   then `cd Haven && xcodegen generate`.

2. **Deploy the backend to prod** (one-time + on every backend change):
   ```bash
   npx convex deploy            # pushes schema + functions to prod (focused-turtle-754)
   ```
   Optional (live food AI in prod; otherwise it falls back to the on-device engine):
   ```bash
   npx convex env set ANTHROPIC_API_KEY sk-ant-...   # on the PROD deployment
   ```
   Keep dev seedable:
   ```bash
   npx convex env set ALLOW_SEED true   # on the DEV deployment only
   ```

3. **App Store Connect app record** — create the app: name "Haven", bundle ID `app.haven.Haven`, primary language, category (Health & Fitness), SKU.

4. **Privacy** (required — this app handles health data):
   - Host a **privacy policy** and put its URL in ASC.
   - Fill the **App Privacy** questionnaire. We collect health/wellness data (migraine logs, symptoms), coarse location (weather), and store it linked to a per-install ID (not to a name/email). No tracking/ads.

5. **Listing metadata** — description, keywords, support URL, screenshots (6.7" + 6.1" at minimum). I can draft copy and we can capture screenshots from the simulator.

## Archive → TestFlight (after steps 1–2)

```bash
cd Haven
xcodegen generate
xcodebuild -project Haven.xcodeproj -scheme Haven \
  -destination 'generic/platform=iOS' \
  -archivePath build/Haven.xcarchive archive

# Upload — easiest is Xcode Organizer (Window → Organizer → Distribute App → TestFlight),
# or via an App Store Connect API key with notarytool/altool.
```

Then in App Store Connect → TestFlight: add yourself as an internal tester, install via the TestFlight app on a real device, verify, then **Submit for Review** from the App Store tab.

## Notes / follow-ups (not blocking v1)
- **Server-side receipt validation** (`convex/billing.ts`) is a trusting stub today; harden before the v1.1 paid release using the App Store Server API.
- **Real PDF report** — the profile export is a plain-text share stub.
- The local `Haven.storekit` config drives in-simulator purchases only; v1.1 needs real subscription products created in ASC matching `haven.yearly` / `haven.weekly`.

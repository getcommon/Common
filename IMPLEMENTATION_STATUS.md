# Common — Implementation Status

Last updated: 2026-09-19

`PRODUCT_BRIEF.md` is the product source of truth. The current implementation is a light-mode-first pass of the core, friendship-first flow.

## Completed today

- **Discover:** Replaced the legacy dashboard with a single editorial public profile. It presents only first name, optional age, photo, bio, interests, shared-interest context, and a coarse distance band.
- **Live discovery:** `HomePage` now renders the highest-ranked eligible `ProximityMatch`. Eren is a debug-only local visual fixture when no seeded match is available; release builds show an empty state instead.
- **Matching privacy:** `ProximityService` enforces the selected radius and distance-aware compatibility thresholds. Public distance display is limited to `under 0.3 mi`, `under 0.5 mi`, or `under 1 mi`.
- **Waves:** Added a daily three-wave allowance to the Discover UI and client write path. The count includes every wave sent today. A Firestore index was added for this count.
- **Activity:** Replaced the former tabbed Waves screen with a timeline for mutual connections and incoming waves. A mutual wave opens a quiet connection sheet with a conversation action.
- **Inbox and chat:** Restyled the mutual-conversations Inbox and conversation detail screen while preserving existing real-time messages and read tracking.
- **Profile and settings:** Profile is now an editorial identity-first surface: photo, name, bio, interests, and a compact privacy-safe discovery row. Major and class year are not shown. Privacy guidance, blocked members, and account actions live in the dedicated Settings page.
- **Edit Profile:** Replaced the legacy card-heavy editor with a calm editorial form: back-to-Profile action, Save action, compact photo control, underline fields, soft interest chips, and on-demand interest/vibe pickers. The editor still preserves location, radius, and vibe tags when it saves.
- **Safety:** Implemented hide, block, report, and unmatch flows through `SafetyService`. Blocked members are excluded from Discover, Activity, and Inbox.
- **Functions runtime:** Firebase Functions now use Node.js 22 and `firebase-functions` 7.4.x. The current functions deployment completed successfully.
- **Radius:** Version-one discovery is capped at the brief’s preferred `under 0.5 mi` range (`0.8 km` internally).
- **Discoverability onboarding:** After a new member completes their profile, Common presents an explicit nearby-discovery choice. Location permission is requested only when they choose to enable it; “Not now” keeps discovery paused, and permanent denial has a device-settings recovery path.
- **Presence expiry:** Location updates now carry a ten-minute expiry and are refreshed every five minutes while Common is active. `findNearbyMatches` requires the caller and every candidate to be visible, unexpired, and recently refreshed on the server.
- **Location boundary:** Firestore rules require location freshness writes to use the request’s server timestamp and cap an active presence at ten minutes. The raw profile callable is now self-only; public discovery uses its minimal derived profile response.

## Important implementation notes

- `mobile/lib/data/discover_profiles.dart` maps a live `ProximityMatch` into public-profile presentation data. It also contains Eren’s debug fixture and portrait.
- `mobile/lib/pages/home_page.dart` is Discover; `waves_page.dart` is Activity; `conversations_page.dart` is Inbox; `chat_detail_page.dart` is the conversation detail screen.
- `mobile/lib/pages/profile_page.dart` is the current editorial profile surface; `profile_setup_page.dart` is the editor; `settings_page.dart` owns private account and safety controls.
- The daily Wave cap is enforced in the `sendWave` callable transaction as well as reflected in the client UI. Add emulator coverage for concurrent sends before production.
- Age is optional in the presentation model because `UserProfile` does not yet store an age/date of birth. Do not derive an age from legacy academic fields.
- Dark-mode support has not been completed for the new screens. Several new surfaces intentionally use the approved warm light palette.
- The visual mock typography is not yet a bundled app font. The current recommendation is to add DM Sans as a cross-platform asset and apply it through `AppTypography`.
- The existing app needs at least two active, nearby accounts with enough shared interests to demonstrate live discovery. Eren is only a debug fallback.

## Verification run today

From `mobile/`:

```sh
flutter analyze
flutter test test/models/user_profile_test.dart -r expanded
flutter test test/services/proximity_service_test.dart -r expanded
flutter test test/models/wave_models_test.dart -r expanded
flutter test test/models/chat_models_test.dart -r expanded
```

The analyzer and each focused suite passed after the corresponding changes.

## Suggested next steps

1. Bundle and apply the editorial typography system consistently across the app (DM Sans is the current recommendation).
2. Test permission denial, enabling, backgrounding, and returning to the app on physical devices; tune the ten-minute presence window if needed.
3. Add emulator coverage for daily wave races and matching thresholds.
4. Complete a dark-mode styling pass across Discover, Activity, Inbox, conversation detail, Profile, Settings, and Edit Profile.
5. Exercise the entire flow with two real nearby test accounts, then remove or migrate remaining legacy student/campus language in older onboarding or unused paths.

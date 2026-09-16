# Common — Implementation Status

Last updated: 2026-09-15

`PRODUCT_BRIEF.md` is the product source of truth. The current implementation is a light-mode-first pass of the core, friendship-first flow.

## Completed today

- **Discover:** Replaced the legacy dashboard with a single editorial public profile. It presents only first name, optional age, photo, bio, interests, shared-interest context, and a coarse distance band.
- **Live discovery:** `HomePage` now renders the highest-ranked eligible `ProximityMatch`. Eren is a debug-only local visual fixture when no seeded match is available; release builds show an empty state instead.
- **Matching privacy:** `ProximityService` enforces the selected radius and distance-aware compatibility thresholds. Public distance display is limited to `under 0.3 mi`, `under 0.5 mi`, or `under 1 mi`.
- **Waves:** Added a daily three-wave allowance to the Discover UI and client write path. The count includes every wave sent today. A Firestore index was added for this count.
- **Activity:** Replaced the former tabbed Waves screen with a timeline for mutual connections and incoming waves. A mutual wave opens a quiet connection sheet with a conversation action.
- **Inbox and chat:** Restyled the mutual-conversations Inbox and conversation detail screen while preserving existing real-time messages and read tracking.
- **Profile:** Rebuilt the Profile tab around identity, interests, discoverability, radius, and privacy guidance. Exact coordinates, email, major, and class year are no longer displayed. The editor preserves location, radius, and vibe tags when it saves.
- **Radius:** Version-one discovery is capped at the brief’s preferred `under 0.5 mi` range (`0.8 km` internally).

## Important implementation notes

- `mobile/lib/data/discover_profiles.dart` maps a live `ProximityMatch` into public-profile presentation data. It also contains Eren’s debug fixture and portrait.
- `mobile/lib/pages/home_page.dart` is Discover; `waves_page.dart` is Activity; `conversations_page.dart` is Inbox; `chat_detail_page.dart` is the conversation detail screen.
- `mobile/lib/pages/profile_page.dart` is the current privacy-safe profile/settings surface. `profile_setup_page.dart` is the editor.
- The daily Wave cap is currently **client-enforced** in `WaveService`. Before production, enforce it server-side as well to prevent bypasses or races.
- Age is optional in the presentation model because `UserProfile` does not yet store an age/date of birth. Do not derive an age from legacy academic fields.
- Dark-mode support has not been completed for the new screens. Several new surfaces intentionally use the approved warm light palette.
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

1. Build the onboarding and location-permission flow around discoverability, coarse-location privacy, and the 0.5-mile default.
2. Add working safety controls: hide, block, report, and unmatch. These are required by the product brief and currently only described in Profile copy.
3. Enforce the daily Wave limit on the server and add tests for the new matching thresholds and daily-count behavior.
4. Complete a dark-mode styling pass across Discover, Activity, Inbox, conversation detail, and Profile.
5. Remove or migrate remaining legacy student/campus language outside the redesigned tabs, especially older onboarding and any unused flows.

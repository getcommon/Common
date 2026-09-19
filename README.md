# Common Grounds

Common is a Flutter app for making genuine local friendships through meaningful shared interests and proximity. It is intentionally friendship-first: no dating language, swiping, public exact-location data, or engagement-driven mechanics.

## Current product state

The app currently has the version-one core flow:

- **Discover** — a warm, editorial nearby-person experience backed by real proximity matching.
- **Activity** — received waves and mutual connections, replacing the legacy three-tab Waves screen.
- **Inbox** — mutual conversations and real-time chat.
- **Profile** — an editorial, identity-first profile with interests and privacy-safe local discoverability.
- **Settings** — privacy context, blocked members, and account actions separated from the public-facing Profile surface.
- **Safety** — hide, block, report, and unmatch actions. Blocked members are filtered from Discover, Activity, and Inbox.

The source of truth for product constraints is [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md). For a detailed handoff and remaining work, start with [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

## Design direction

- Warm, white-first editorial light mode with restrained terracotta accents.
- Calm, friendship-first language and reversible actions.
- Profiles expose only a name, photo, bio, interests, and broad discovery context. Exact coordinates, contact details, school/major, class year, and safety controls are not public profile content.
- The Profile and Edit Profile screens are now the current visual reference for the personal-account experience.

## Architecture

| Layer | Technology |
| --- | --- |
| Mobile client | Flutter / Dart |
| Identity | Firebase Authentication |
| App data | Cloud Firestore |
| Profile media | Firebase Storage |
| Server workflows | Firebase Cloud Functions v2, Node.js 22 |
| Notifications | Firebase Cloud Messaging |
| Location | Geolocator + privacy-preserving geohash/proximity queries |

The Firebase project configured for this app is `blue4-commongrounds`. Do not commit API keys, testing credentials, or private Firebase configuration beyond the platform config files already required by the app.

## Run locally

Prerequisites: Flutter 3.35.5+ with Dart 3.9.2+, Xcode for iOS, and an authenticated Firebase CLI only when deploying backend changes.

```sh
cd mobile
flutter pub get
flutter run
```

To target a simulator explicitly:

```sh
cd mobile
flutter run -d "iPhone 16 Pro Max"
```

## Verify changes

```sh
cd mobile
flutter analyze
flutter test
```

For a focused UI change, analyze the files you edited as well:

```sh
dart analyze lib/pages/profile_page.dart lib/pages/profile_setup_page.dart
```

## Firebase Functions

Functions live in `mobile/functions/` and use Node.js 22 with `firebase-functions` 7.4.x.

```sh
cd mobile/functions
npm install
npm run build
firebase deploy --only functions
```

Key callable workflows include `sendWave`, `respondToWave`, `findNearbyMatches`, and `getUserProfile`. Before changing wave rules, preserve the server/client contract and update both matching tests and Firestore rules as appropriate.

## Repository map

```text
mobile/
├── lib/
│   ├── app_shell.dart                # Persistent four-tab navigation
│   ├── pages/                        # Discover, Activity, Inbox, Profile, Settings
│   ├── services/                     # Firebase, matching, location, messaging, safety
│   ├── models/                       # Firestore-backed data models
│   ├── core/theme/                   # Color, spacing, and typography tokens
│   └── widgets/                      # Shared UI components
├── functions/                        # Firebase Functions v2 (Node.js 22)
├── firestore.rules                   # Firestore access policy
└── pubspec.yaml                      # Flutter dependencies and assets
```

## Next work

1. Bundle and apply the selected editorial typography system consistently across the app (the recommended cross-platform choice is DM Sans; it is not installed yet).
2. Add server-side presence freshness/expiry enforcement and test permission denial, enabling, backgrounding, and return behavior.
3. Add emulator tests for daily-wave races/bypass attempts and matching thresholds.
4. Complete the dark-mode pass for the redesigned screens.
5. Exercise the full flow using two real nearby test accounts: Discover → wave → mutual → Activity → Inbox.

## License

MIT. See [LICENSE](LICENSE).

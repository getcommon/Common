# Common mobile app

Flutter implementation of Common, a friendship-first local discovery app. The product constraints and current handoff live in the repository root:

- [Product brief](../PRODUCT_BRIEF.md)
- [Implementation status](../IMPLEMENTATION_STATUS.md)
- [Repository overview](../README.md)

## Start here

```sh
flutter pub get
flutter run
```

Use `flutter devices` to see targets, then run a simulator explicitly if needed:

```sh
flutter run -d "iPhone 16 Pro Max"
```

## Current navigation

`lib/app_shell.dart` keeps the four primary tabs alive with an `IndexedStack` so tab changes do not rebuild into blank/loading states:

1. **Discover** — `pages/home_page.dart`
2. **Activity** — `pages/waves_page.dart` (`ActivityPage`; `WavesPage` is deprecated compatibility naming)
3. **Inbox** — `pages/conversations_page.dart`
4. **Profile** — `pages/profile_page.dart`

Profile details:

- `pages/profile_page.dart` is the editorial profile surface.
- `pages/profile_setup_page.dart` is the real **Edit Profile** editor.
- `pages/settings_page.dart` owns privacy explanation, blocked members, and account actions.
- Location controls are shown compactly on Profile and open a focused sheet; no precise location is displayed.

## Important implementation rules

- Preserve actual Firestore wave, mutual-match, chat, safety, and location workflows when restyling UI.
- Do not show precise coordinates, school/major, class year, email, or safety/account controls on the profile surface.
- Keep copy friendship-first. Avoid dating language, celebratory match mechanics, generic dashboard cards, and swiping.
- Safety filtering is centralized in `services/safety_service.dart`; blocked members must stay absent from Discover, Activity, and Inbox.
- `LocationService` intentionally pauses discoverability in the background. Do not reintroduce automatic background presence.

## Verify

```sh
flutter analyze
flutter test
```

For quicker iteration, analyze only the files changed:

```sh
dart analyze lib/pages/profile_page.dart lib/pages/profile_setup_page.dart lib/pages/settings_page.dart
```

## Theme and typography

Warm colors and current type tokens are in `lib/core/theme/`. The next typography milestone is to bundle a real cross-platform editorial font (DM Sans is the working recommendation) and apply consistent display, body, and label tokens. Do not rely on a browser mock font or an iOS-only system font for a cross-platform design decision.

## Backend companion

Firebase Functions are in `functions/`; see the root README for deployment commands. The functions runtime is Node.js 22.

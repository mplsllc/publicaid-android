# Publicaid Android

Native Flutter app for [publicaid.org](https://publicaid.org) — national directory of social services.

## Stack

- **Framework:** Flutter 3.41.1, Dart 3.11.0
- **UI:** Material 3, custom theme (navy/blue palette)
- **State:** ChangeNotifier + built-in Provider (no codegen, no riverpod)
- **Network:** `http` package (lightweight)
- **Storage:** `shared_preferences` (bookmarks, prefs), `flutter_secure_storage` (auth tokens)
- **Auth:** Token-based + `local_auth` for biometric/device credential login
- **Fonts:** InstrumentSerif (headlines), DMSans (body) — in assets/fonts/

## Key Commands

```bash
flutter run                # Hot reload dev mode
flutter build apk --debug  # Debug APK
flutter build apk          # Release APK
flutter analyze            # Static analysis
adb install build/app/outputs/flutter-apk/app-debug.apk  # Manual install
```

## Architecture

```
lib/
├── main.dart              # Entry point, portrait lock
├── app.dart               # MaterialApp, service init, tab shell + bottom nav
├── theme.dart             # ThemeData, colors, typography, component themes
├── models/
│   ├── entity.dart        # Entity, EntityCategory, EntityService, EntityHours, DataQuality
│   ├── category.dart      # Category with recursive children
│   ├── auth.dart          # UserData, AuthState, BookmarkItem, AltchaChallenge
│   └── api_response.dart  # Generic ApiResponse<T> with ApiMeta
├── services/
│   ├── api_service.dart   # HTTP client, auth header injection, all endpoints
│   ├── auth_service.dart  # Login/register/logout, token mgmt, biometric, credential persistence
│   ├── bookmark_service.dart  # Local + remote bookmark sync, optimistic toggle
│   └── location_service.dart  # Permission + position wrapper, US-center fallback
├── screens/
│   ├── home_screen.dart       # Hero gradient, search card, category grid
│   ├── search_screen.dart     # Infinite scroll, filter sheet, active chips
│   ├── detail_screen.dart     # Full entity view, actions, hours, services
│   ├── bookmarks_screen.dart  # Saved services, pull-to-refresh
│   ├── categories_screen.dart # Hierarchical category list
│   ├── account_screen.dart    # Auth state card, profile, links
│   ├── login_screen.dart      # Email/password + biometric option
│   └── register_screen.dart   # Form + ALTCHA widget
└── widgets/
    ├── entity_card.dart   # Result card with tags, distance, actions
    ├── search_bar.dart    # Reusable search input
    ├── altcha_widget.dart # SHA-256 proof-of-work checkbox
    └── bottom_nav.dart    # 5-tab navigation
```

## API

- Base URL: `https://publicaid.org/api/v1/`
- Auth: Bearer token auto-attached via ApiService
- Endpoints in `api_service.dart` (search, entities, categories, filters, user auth, bookmarks, ALTCHA)

## Secrets

- `google-services.json` — stored in Infisical, NOT in repo. Inject at build time.
- Auth tokens — `flutter_secure_storage` (Android Keystore backed)
- See @memory for Infisical access details.

## Android Config

- Package: `org.publicaid.app`
- Min SDK: Flutter default (21)
- Manifest: INTERNET, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION, USE_BIOMETRIC

## Git

- Remote: `git@github.com:mplsllc/publicaid-android.git`
- Branch: `main`
- Commit style: conventional commits (`feat:`, `fix:`, `refactor:`)

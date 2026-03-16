# Current Work State — Updated 2026-03-15

## Just Completed
- Full rewrite from native Kotlin/Compose to Flutter
- 22 Dart files, zero analysis issues, installed on Pixel 9
- All 8 screens ported: Home, Search, Detail, Bookmarks, Categories, Account, Login, Register
- Auth system: token storage, biometric re-auth, ALTCHA proof-of-work
- Slim dependency footprint: http, shared_preferences, flutter_secure_storage, local_auth, url_launcher, share_plus, crypto
- GOOGLE_SERVICES_JSON stored in Infisical (secret ID: e05a5bb4-3ba7-436b-baca-d811e9bc33ea)
- google-services.json excluded from repo via .gitignore

## TODO
- Firebase/FCM setup for push notifications (google-services.json in Infisical, needs Firebase Flutter plugin + notification service)
- Wire ALTCHA challenge endpoint on server (`GET /api/altcha/challenge`) if not already present
- App icon — currently using Flutter default
- Splash screen customization
- CI/CD pipeline (inject google-services.json from Infisical at build time)
- Test on more devices / screen sizes

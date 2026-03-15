# Publicaid Android

Native Android app for [Publicaid](https://publicaid.org) — find social services near you.

A lightweight search client for the Publicaid directory of 154,000+ verified social service listings across the United States. Food, housing, healthcare, mental health, substance use treatment, legal aid, and more.

## Features

- **Find help near me** — location-aware search with distance sorting
- **Browse by category** — 15 service categories
- **Full-text search** — with filters for state, language, payment type, population served
- **Click-to-call** — tap to dial any service's phone number
- **Navigate** — open directions in Google Maps
- **Share** — send a service to someone via text, WhatsApp, etc.
- **Save for offline** — bookmark services for offline access
- **Accessible** — large touch targets, screen reader support, dynamic text sizing
- **Privacy-first** — no analytics, no tracking, no location persistence

## Architecture

5 screens, thin API client:

```
Home → Search Results → Entity Detail
         ↓                    ↓
    Categories            Bookmarks (offline)
```

- **Kotlin + Jetpack Compose** with Material 3
- **Retrofit + Moshi** for API communication
- **Room** for offline bookmarks and search cache
- **Hilt** for dependency injection
- **WorkManager** for background bookmark sync

## Building

```bash
# Clone
git clone https://github.com/mplsllc/publicaid-android.git
cd publicaid-android

# Set SDK path
echo "sdk.dir=/path/to/android-sdk" > local.properties

# Build
./gradlew assembleDebug
```

## API

The app consumes the [Publicaid API](https://publicaid.org/api/docs) (free, open access at 30 req/min). The embedded API key is rate-limited and rotatable — please don't abuse it.

## License

GPL-3.0. See [LICENSE](LICENSE).

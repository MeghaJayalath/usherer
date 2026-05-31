# Usherer ✈️🚐

Usherer is a premium, real-time flight status tracking, vehicle coordination, and passenger manifest management application designed for tourist logistics and greeting operations. 

Built with **Flutter & Dart**, Usherer acts as an intelligent bridge between operational spreadsheets and ground team coordinates, providing a dark-mode glassmorphic dashboard with instant local updates and flight-level status notifications.

---

## 🌟 Key Features

*   **Dynamic API Key Quota Tracker**: Dashboard-integrated status bar monitoring of remaining RapidAPI requests across multiple keys. Features automated alert coloring: **Green** (Healthy), **Yellow** (Warning, <50%), and **Accent Coral** (Critical, <20%) with automatic hot rotation when keys are rate-limited or exhausted.
*   **Two-Way Sheets Auto-Sync**: Seamless, non-blocking synchronization with Google Sheets. Updates made in Google Sheets auto-sync to your local dashboard, and flight status changes auto-write back to your sheet.
*   **Intelligent Flight Poller**: Live, background flight tracking leveraging custom interval pacing to safely protect and maximize hourly API rate limits.
*   **Deduplicated Time-Normalized Notifications**:
    *   *Time Normalization*: standardizes all time formats (2:30 PM, 14:30:00, 14.30) to eliminate redundant notification loops caused by cell-formatting variations.
    *   *Flight Deduplication*: Intelligently tracks and triggers **exactly one push notification per flight status update**, even if passengers are split across 10 different vehicles!
*   **Premium Visuals & Dark Mode**: Modern design built around smooth animations, custom VIP indicators, status badges, and fluid layouts for a professional ground-handling experience.

---

## 🛠️ Technology Stack

*   **Core**: [Flutter SDK](https://flutter.dev) (Dart)
*   **Database & Cache**: [Hive](https://pub.dev/packages/hive) (For high-speed, local offline storage of credentials, sheets data, and API quotas)
*   **Live Cloud Synced State**: [Cloud Firestore](https://firebase.google.com) (Real-time admin/ground synchronization)
*   **Spreadsheet Engine**: [Google Sheets API](https://developers.google.com/sheets/api)
*   **Background Tasks**: [Workmanager](https://pub.dev/packages/workmanager) (For background live flight polls)
*   **Notifications**: [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)

---

## ⚙️ Project Structure

```text
lib/
├── core/
│   ├── services/
│   │   ├── firestore_service.dart      # Real-time Cloud syncing
│   │   ├── flight_api_service.dart     # RapidAPI AeroDataBox + Key Rotation
│   │   ├── notification_service.dart   # Local Push Notifications
│   │   └── sheets_service.dart         # Google Sheets parser and writer
│   └── theme/
│       └── app_colors.dart             # Curated accent palette
├── data/
│   ├── local/
│   │   └── hive_cache.dart             # Local preferences & quota cache
│   ├── models/
│   │   ├── flight.dart                 # Flight status calculators & time normalizer
│   │   ├── tourist.dart                # Individual tourist record model
│   │   └── tourist_group.dart          # Vehicle/Flight grouping logic
│   └── repositories/
│       ├── flight_repository.dart      # Live polling coordinator
│       └── tourist_repository.dart     # Manifest syncing repository
├── features/
│   ├── dashboard/                      # Main screen with glassmorphic cards
│   └── settings/                       # Admin settings panel with Quota Dashboard
└── main.dart                           # Entrypoint, Hive initialization & Workmanager
```

---

## 🚀 Setup & Installation

### 1. Prerequisites
Ensure you have the Flutter SDK installed on your machine.
```bash
flutter doctor
```

### 2. Configure Google Sheets & Firebase
Add your credentials to `lib/app_config.dart` and configure your `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) files.

### 3. Install Dependencies
Run the package installer from the project root:
```bash
flutter pub get
```

### 4. Run the Project
Start your app in debug or release mode:
```bash
flutter run
```

---

## 📄 License
This project is for personal use and operational coordination. Designed with ❤️ for flawless tourist transitions.

# KisanPro Milk Monitoring (Version 1)

A professional, feature-rich Flutter application designed for dairy farmers and livestock managers. This application simplifies recording, tracking, and analyzing milk yield, quality (Fat & SNF percentages), and session metrics on an individual cattle basis.

---

## Key Features

* **Session-wise Milk Logging**: Record precise yield (in liters), Fat percentage (e.g., 4.5%), and Solids-Not-Fat (SNF) percentage (e.g., 8.5%) for specific cattle, categorized by milking session (Morning/Evening).
* **Robust Analytics Dashboard**: Visual summary of daily total production, morning vs. evening splits, rolling weekly/monthly yields, average daily yield, and identifies peak production days.
* **Interactive Data Visualization**: Integrates line graphs and bar charts via `fl_chart` to track milk production trends over time.
* **On-the-go PDF Report Generation**: Dynamically compile and generate custom PDF reports containing analytics charts, summaries, and individual logs. Supports direct PDF printing or sharing.
* **Cloud Sync with Local Fallback**: Integrates directly with Cloud Firestore. If Firebase credentials are missing or connection fails, the app automatically switches to a local simulation mode, ensuring continuous operation.
* **Adaptive Light & Dark Modes**: Responsive interface that respects the host operating system's theme preference.

---

## Tech Stack & Dependencies

* **Framework**: [Flutter SDK](https://flutter.dev/) (SDK version: `>=3.4.0 <4.0.0`)
* **State Management**: [Provider](https://pub.dev/packages/provider) — clean, predictable state management using ChangeNotifier architecture.
* **Backend Database**: [Cloud Firestore](https://pub.dev/packages/cloud_firestore) (Firebase Core).
* **Data Visualization**: [FL Chart](https://pub.dev/packages/fl_chart) for rendering fluid, responsive analytics curves.
* **Document Compilation**: [PDF](https://pub.dev/packages/pdf) and [Printing](https://pub.dev/packages/printing) for programmatic canvas PDF exports.
* **Utilities**: `intl` for datetime formats and `google_fonts` for clean, professional typography.

---

## Architecture & Directory Structure

The module follows a clean, feature-first structure:

```text
lib/
├── core/
│   └── theme/
│       └── app_theme.dart                 # Custom light & dark theme styling configurations
├── features/
│   └── milk_monitoring/
│       ├── data/
│       │   ├── models/
│       │   │   ├── milk_record_model.dart  # Data model for individual session yields
│       │   │   └── milk_analytics_model.dart # Data model for daily/weekly/monthly analytics
│       │   └── services/
│       │       ├── milk_firestore_service.dart # Real Firebase database API controller
│       │       └── mock_milk_service.dart     # Fail-safe local simulation API
│       ├── domain/
│       │   └── repositories/
│       │       └── milk_repository.dart    # Abstract contract defining data access layer
│       └── presentation/
│           ├── providers/
│           │   └── milk_provider.dart      # View-model state manager and controller
│           ├── screens/
│           │   ├── milk_monitoring_screen.dart # Dashboard/Input main view
│           │   ├── milk_analytics_screen.dart  # Visual graph analysis screen
│           │   ├── milk_history_screen.dart    # Tabular list of past records
│           │   └── milk_report_screen.dart     # PDF generation & preview canvas
│           └── widgets/
│               ├── analytics_card.dart
│               ├── milk_chart_widget.dart
│               └── recent_entry_tile.dart
└── main.dart                               # Flutter bootstrap class & MultiProvider loader
```

---

## Setup & Installation Instructions

### Prerequisites
* Flutter SDK installed (v3.4.0 or higher)
* Android SDK / Xcode (for running on emulator or physical devices)
* A configured Firebase project (optional)

### Setup Steps

1. **Clone and navigate to the directory**:
   ```bash
   cd "Cattle-Monitoring/Milk Monitoring/Milk monitoring version1"
   ```

2. **Fetch packages**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration Setup (Optional)**:
   To synchronize data with your Firebase console:
   * **Android**: Download `google-services.json` from your Firebase dashboard and place it under `android/app/`.
   * **iOS**: Download `GoogleService-Info.plist` and add it via Xcode to your runner project structure.
   
   *Note: If you skip this setup, the app will safely run in **simulation mode** using locally generated data.*

4. **Run the app**:
   ```bash
   # Run on your default connected device/simulator
   flutter run
   ```

5. **Build the production executable**:
   * For Android:
     ```bash
     flutter build apk --release
     ```
   * For iOS:
     ```bash
     flutter build ipa --release
     ```

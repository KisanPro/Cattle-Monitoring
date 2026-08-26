# Component Inventory

**Project**: KisanPro — Cattle Milk Monitoring  
**Version**: 1.0

---

## Application Packages (Flutter)

| Package | Type | Purpose |
|:--------|:-----|:--------|
| `integrated_feature_module` | Flutter Feature Module | Complete plug-in milk monitoring module for embedding in any Flutter app |
| `standalone_source_lib` | Flutter Standalone App | Self-contained Flutter app source (full app with main.dart entry point) |

---

## Infrastructure Packages

| Package | Technology | Purpose |
|:--------|:-----------|:--------|
| `backend/` | Python / FastAPI | REST API server deployed on AWS EC2 |
| AWS EC2 `kisan-milk-server` | Amazon EC2 t3.micro | Hosts FastAPI backend, port 8082 |
| AWS RDS `database-1` | Amazon RDS PostgreSQL 18.3 | Persistent cloud database |

---

## Shared Packages

| Package | Type | Purpose |
|:--------|:-----|:--------|
| `data/models/milk_record_model.dart` | Data Model | Core MilkRecordModel shared across all services and screens |
| `data/models/milk_analytics_model.dart` | Data Model | MilkAnalyticsModel for aggregated stats |
| `domain/repositories/milk_repository.dart` | Interface | Repository abstract class — contracts all service implementations |

---

## Data Service Implementations

| Service | Type | Status | Purpose |
|:--------|:-----|:-------|:--------|
| `MockMilkService` | Local Simulation | Active | Offline demo data — 80 pre-generated records for 4 cattle |
| `PostgresMilkService` | AWS Cloud | Active | Live service — polls AWS EC2 every 4 seconds via HTTP |
| `MilkFirestoreService` | Firebase Legacy | Deprecated | Replaced by PostgresMilkService; kept for historical reference |

---

## APK Deliverables

| APK | Size | Mode | Status |
|:----|:-----|:-----|:-------|
| `Milk_Monitoring_AWS_PostgreSQL_v1.0.apk` | 49.5 MB | Release — AWS Live | Current recommended production APK |
| `KisanPro_Universal_v1.0.apk` | 108.6 MB | Release — Full KisanPro | Older universal build |
| `milk_monitoring_debug.apk` | 404 MB | Debug — Full logging | Development/testing only |
| `kisan_pro_milk_monitoring.apk` | 404 MB | Debug — Full KisanPro | Original full app debug build |

---

## Screens (Flutter Presentation Layer)

| Screen | File | Purpose |
|:-------|:-----|:--------|
| MilkMonitoringScreen | `milk_monitoring_screen.dart` | Root — tab navigation host |
| DashboardTab | (embedded in milk_monitoring_screen) | Farm metrics, AI insights, recent entries |
| MilkAnalyticsScreen | `milk_analytics_screen.dart` | Charts, quality metrics, production trends |
| MilkHistoryScreen | `milk_history_screen.dart` | Filterable milking logbook |
| MilkReportScreen | `milk_report_screen.dart` | PDF report generator |

---

## Widgets (Flutter Presentation Layer)

| Widget | File | Purpose |
|:-------|:-----|:--------|
| MilkEntryCard | `milk_entry_card.dart` | New milk record entry form |
| MilkSummaryCard | `milk_summary_card.dart` | Daily production summary card |
| RecentEntryTile | `recent_entry_tile.dart` | Grouped recent entry list tile |
| AnalyticsCard | `analytics_card.dart` | Single analytics metric display card |
| MilkChartWidget | `milk_chart_widget.dart` | Line/bar production chart |
| CattleReportModal | `cattle_report_modal.dart` | Per-cattle detail bottom sheet modal |

---

## Backend Scripts

| Script | Language | Purpose |
|:-------|:---------|:--------|
| `main.py` | Python 3.14 / FastAPI | Core API server |
| `schema.sql` | PostgreSQL SQL | DDL for all database tables |
| `init_db.py` | Python | First-time database initialization |
| `seed_cloud_data.py` | Python | Populate 240 demo records into AWS RDS |
| `test_connection.py` | Python | Connectivity test for AWS RDS |

---

## Total Count Summary

| Category | Count |
|:---------|:------|
| **Flutter Screens** | 5 (Dashboard, Analytics, History, Report, Root) |
| **Flutter Widgets** | 6 |
| **Data Models** | 2 (MilkRecordModel, MilkAnalyticsModel) |
| **Service Implementations** | 3 (Mock, PostgreSQL, Firebase legacy) |
| **Backend Scripts** | 5 |
| **APK Deliverables** | 4 |
| **AWS Services** | 2 (EC2, RDS) |
| **Total Source Files** | ~30 |

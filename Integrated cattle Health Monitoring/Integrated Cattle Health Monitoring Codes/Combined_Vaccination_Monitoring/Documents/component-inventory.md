# Component Inventory

## Application Packages
- **`lib/features/vaccination_monitoring/presentation/screens/`** - Frontend views containing inputs, dashboard, reports, history, AI alerts page, and detail overlays.
- **`lib/features/vaccination_monitoring/presentation/providers/`** - State managers and controllers.
- **`lib/features/vaccination_monitoring/presentation/widgets/`** - Customized cards, graphs, and table rows.

## Infrastructure Packages
- **`AWS API Gateway: VaccinationMonitoringAPI`** - Secure REST routing gateway.
- **`AWS Lambda: vaccinationMonitoringBackend`** - Microservice router running Node.js runtime.
- **`DynamoDB: Vaccinations Table`** - Scalable vaccinations database.
- **`DynamoDB: Reminders Table`** - Scalable scheduled alerts database.

## Shared Packages
- **`lib/core/theme/`** - Visual parameters containing custom colours, buttons, inputs, and fonts.
- **`lib/core/utils/`** - PDF printing modules.
- **`lib/features/vaccination_monitoring/data/models/`** - Shared datamodels.
- **`lib/features/vaccination_monitoring/data/services/`** - Communication services (AWS REST interface, Mock database, AI Prediction rules engine, Local notifications).
- **`lib/features/vaccination_monitoring/data/repositories/`** - Bridge layer matching UI updates to network states.

## Test Packages
- **`test/vaccination_monitoring_test.dart`** - Unit tests verifying models serialization and provider analytics logic.
- **`test/widget_test.dart`** - Widget tests validating app launch layouts.

---

## Total Count
- **Total Packages/Modules**: 12
- **Application (UI & State)**: 3
- **Infrastructure (AWS Backend)**: 4
- **Shared (Core Utilities & Models)**: 5
- **Test**: 2

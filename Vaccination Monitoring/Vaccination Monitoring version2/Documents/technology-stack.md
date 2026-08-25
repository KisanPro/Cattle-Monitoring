# Technology Stack

## Programming Languages
- **Dart (v3.4.0)** - Primary language for the cross-platform mobile app development.
- **JavaScript / Node.js (v24.x)** - Used for scripting serverless Lambda backend handlers.

## Frameworks
- **Flutter SDK (v3.22.x)** - Framework for building native Android/iOS mobile views.
- **AWS SDK for JavaScript v3** - Libraries (`@aws-sdk/client-dynamodb`, `@aws-sdk/lib-dynamodb`) to interact with DynamoDB tables from Lambda.

## Infrastructure
- **Amazon API Gateway** - Deploys REST interfaces and manages CORS.
- **AWS Lambda** - Executes serverless script requests.
- **Amazon DynamoDB** - Managed NoSQL cloud storage database.

## Build Tools
- **Gradle (v8.x)** - Android compiler engine.
- **Flutter CLI** - Builds APK targets and manages local run syncs.
- **Pub Package Manager** - Resolves dependencies in the Flutter project.

## Testing Tools
- **`flutter_test`** - Compiles assertions, mocks provider streams, and checks widget launches.

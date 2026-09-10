# User Manual: KisanPro Vaccination Monitoring System

**Objective:**  
To provide a complete step-by-step guide for installation, configuration, operation, troubleshooting, maintenance, and reproduction of the project so that a new user or development team can independently deploy, compile, and use the system.

---

## 1. What is the Project?

### 1.1 Project Purpose
The **KisanPro Vaccination Monitoring System** is a professional-grade veterinary tracking solution designed to help livestock farmers monitor animal vaccination compliance. The application logs administered vaccine details, automatically computes recommended booster dates based on standard veterinary intervals, alerts users via local push notifications when boosters are due, and compiles detailed history reports.

### 1.2 Problem Being Solved
*   **Missed Booster Doses:** Tracking multiple cattle manually often results in missed booster doses, reducing vaccine efficacy.
*   **Compliance Rates Tracking:** Farmers and veterinary officers need clear statistics on overall herd immunity.
*   **Connectivity Constraints:** Farmers frequently operate in areas with unstable internet connections. The app must run offline gracefully.
*   **Disease Vulnerability Analysis:** Standard tracking lists do not advise farmers of upcoming environmental disease risks or weight-loss related illnesses.

### 1.3 Key Features
*   **New Vaccine Logging:** Computes next booster dates (e.g. 30 days for FMD, 180 days for HS, 365 days for Anthrax) based on admin date.
*   **Cattle Metrics Integration:** Logs Cattle Name, Cattle ID, Age (Years), Weight (kg), Breed Name, and Farmer Location.
*   **AI Disease & Vaccination Predictor:** Generates real-time disease risk assessments and preventative vaccination recommendations based on a rule-based AI engine using breed, age, location, and weight.
*   **Active Alarms & Reminders:** Urgency color-coding for Overdue (Red 🔴), Due Today (Orange 🟠), and Upcoming (Yellow 🟡) doses.
*   **Cattle Directory:** Expansion-panel registry grouped by animal IDs.
*   **Realtime Cloud Integration:** Synchronizes data dynamically to AWS DynamoDB.
*   **Offline Fallback:** Seamlessly shifts data queries to a local memory cache if AWS is offline.
*   **Printable PDF Reports:** Generates vector-graphic PDFs containing stats, weekly/monthly charts, and logs.

### 1.4 System Architecture
```
[Flutter Mobile Client]  <--->  [VaccinationRepository]
                                      |
              +-----------------------+-----------------------+
              | (Online)                                      | (Offline Fallback)
    [AWS API Gateway REST API]                       [MockDatabaseService]
              |
     [AWS Lambda Function] (Node.js)
              |
      [Amazon DynamoDB] (Vaccinations & Reminders Tables)
```

---

## 2. What Hardware is Required?

To run, compile, and deploy this project, the following hardware is required:

1.  **Developer Workstation:**
    *   PC or Laptop (Windows 10/11, macOS, or Linux) with at least 8GB RAM (16GB recommended) for compiling and building Android packages.
2.  **Target Mobile Device:**
    *   An Android smartphone (Android 6.0 / API 23 or higher) or iOS device to run the app.
3.  **USB Cable:**
    *   To connect the mobile phone to the developer workstation for testing.
4.  **Network Router / Connectivity:**
    *   A Wi-Fi router or cellular data connection to allow the mobile device to make HTTPS calls to the AWS cloud database.
5.  **Desktop Printer (Optional):**
    *   A local Wi-Fi or network-capable printer to print generated PDF reports directly from the mobile application.

---

## 3. How to Set Up the Hardware?

1.  **Workstation Connection:**
    *   Connect the mobile device to your computer using a compatible USB data cable.
2.  **Enable Developer Mode on Mobile Phone:**
    *   On the Android phone, go to **Settings > About Phone**.
    *   Tap the **Build Number** 7 times until you see a prompt: *"You are now a developer."*
    *   Go back to **Settings > System > Developer Options**.
    *   Toggle **USB Debugging** to **ON**.
    *   Accept the prompt authorizing the computer's RSA key fingerprint when prompted on the screen.
3.  **Network Setup:**
    *   Ensure both the workstation and the mobile device are connected to the internet (via Wi-Fi or cellular network).
4.  **Printer Pairing:**
    *   Ensure the target mobile phone is on the same local Wi-Fi network as your desktop printer for wireless printing to work.

---

## 4. How to Install the Software?

### 4.1 Developer Workstation Requirements
*   **Flutter SDK:** Version `3.22.x` or higher (installed and added to System PATH).
*   **Java Development Kit (JDK):** JDK 17 (Temurin recommended) configured via `flutter config --jdk-dir`.
*   **Android Studio / SDK:** Installed with Android SDK Platform tools (API 35 SDK, build-tools).

### 4.2 Local Library Installation
Run the following command in the project root folder (`F:\Vaccination Monitoring\Vaccination Monitoring Code`) to download all Dart packages:
```powershell
flutter pub get
```

### 4.3 AWS Cloud Backend Setup
The cloud backend runs on AWS. To set it up from scratch:
1.  **DynamoDB:** Create two tables named `Vaccinations` (Partition Key: `id`, Sort Key: `cattleId`) and `Reminders` (Partition Key: `id`) with standard settings.
2.  **Lambda:** Create a Node.js 24.x function named `vaccinationMonitoringBackend`. Paste the contents of **[vaccinationMonitoringBackend.js](file:///f:/Vaccination%20Monitoring/User_manual/vaccinationMonitoringBackend.js)** into `index.mjs` and click **Deploy**.
3.  **Permissions:** Under Lambda > Configuration > Permissions, click the Role name and attach the policy **`AmazonDynamoDBFullAccess`** to the execution role.
4.  **API Gateway:** Create a REST API named `VaccinationMonitoringAPI`. Setup paths `/farmers/{farmerId}/vaccinations` (GET, POST), `/farmers/{farmerId}/reminders` (GET, POST), and `/farmers/{farmerId}/reminders/{reminderId}` (PUT). Enable **Lambda Proxy Integration** on all methods, click **Enable CORS** (Check GET, POST, PUT), and **Deploy** to a stage named `v1`.
5.  **URL Link:** Update your API Gateway Invoke URL inside [`vaccination_repository.dart`](file:///f:/Vaccination%20Monitoring/Vaccination%20Monitoring%20Code/lib/features/vaccination_monitoring/data/repositories/vaccination_repository.dart) and [`aws_api_service.dart`](file:///f:/Vaccination%20Monitoring/Vaccination%20Monitoring%20Code/lib/features/vaccination_monitoring/data/services/aws_api_service.dart).

### 4.4 APK Installation on Mobile Device
To install the compiled app directly on your connected device, run:
```powershell
flutter install
```
*(Or copy the file `vaccination_monitoring.apk` from the `F:\Vaccination Monitoring\apk` directory to your phone and open it to install).*

---

## 5. How to Run the System?

1.  Verify the mobile device is detected by running:
    ```powershell
    flutter devices
    ```
2.  Start the app in debugging mode:
    ```powershell
    flutter run
    ```
3.  Monitor active system logs in your console or via Android Logcat:
    ```powershell
    adb logcat *:S flutter:I
    ```

---

## 6. How to Use the System?

### 6.1 Logging a Vaccination & Cattle Data
1.  Scroll to the **New Vaccine Entry** card on the dashboard.
2.  Input the following details:
    *   **Cattle ID:** (e.g. `KA-1989` or `KP-204`) - *Type `KA-1989` or `Geetha` to trigger automatic pre-population demo.*
    *   **Cattle Name:** (e.g., `Geetha` or `Lakshmi`).
    *   **Vaccine Name:** (e.g., `FMD Vaccine`).
    *   **Vaccine Date:** Select administering date.
    *   **Cattle Age (Years):** (e.g., `4`).
    *   **Cattle Weight (kg):** Current weight in kilograms (e.g., `380`).
    *   **Cattle Breed:** (e.g., `Hallikar`).
    *   **Farmer Location / State:** (e.g., `Karnataka`). *You can tap the location pin suffix icon next to the field to automatically query and populate your current Indian state using a secure IP lookup service.*
3.  Click **Save Vaccine Entry**. The app records the entry, schedules a local notification booster task, and automatically runs the AI engine to evaluate health threats.

### 6.2 AI Disease Alerts & Awareness
*   **Home Dashboard Widget:** Scroll to the **AI Disease & Vaccination Predictor** list on the home dashboard to view instant summary cards for your herd.
*   **Dedicated AI Health Alerts Screen:** Click the **Sparkles (`Icons.auto_awesome`)** button in the dashboard App Bar to open the full-screen AI Health Alerts console.
*   **Risk Level Filtering:** Use the pills at the top of the AI Alerts screen to filter by risk severity: **All**, **High**, **Medium**, or **Low** risk.
*   **Clinical Advice Popups:** Tap any alert card to launch a detailed clinical popup showing full disease symptoms, recommended veterinary diagnoses (e.g., Milk Ring Test, fecal egg counts), and drug prescriptions (e.g., Albendazole, Sulfadimidine, Oxytetracycline).

### 6.3 Adding Custom Reminders
1.  Go to the **Schedule Custom Reminder** form.
2.  Provide a vaccine name, choose the alert date, and write a description.
3.  Click **Schedule Reminder**.

### 6.4 Checking Alerts & Completing Reminders
*   Check the **Active Alarms & Reminders** panel on the home dashboard for overdue or due doses.
*   Once a booster is administered, click the checkmark button on the reminder tile to mark it as **Completed**.

### 6.5 Viewing & Printing Reports
1.  Click **View Full Report Dialog** at the bottom of any Cattle summary.
2.  Review compliance rates and the performance bar chart.
3.  Click **Generate Report** to launch the printing layout overlay and print or save the PDF file.

---

## 7. How Does the System Work?

### 7.1 Lifecycle of a Vaccine Log
1.  **User Input:** The farmer submits details through the dashboard form.
2.  **Booster Calculations:** The `VaccinationProvider` matches the input vaccine name to compute the booster date:
    *   Anthrax / Brucellosis: 1 Year (365 days)
    *   Hemorrhagic Septicemia (HS): 6 Months (180 days)
    *   Default (FMD / others): 30 Days
3.  **Local Alerts:** Schedules a system push notification alert on the device using `flutter_local_notifications`.
4.  **Network Routing:** `VaccinationRepository` attempts an HTTP POST request via `AwsApiService`.
5.  **Database Write:** AWS API Gateway receives the JSON payload, forwards it to Lambda, which writes the item records into DynamoDB.
6.  **Offline Fallback:** If the HTTP request fails due to network issues, the repository catches the error and redirects the streams to `MockDatabaseService` to allow uninterrupted usage.

### 7.2 Interconnection with Cattle Weight Monitoring
The Vaccination Monitoring app is directly integrated with physical weight statistics:
*   **Weight Loss Warning Triggers:** The AI Prediction Engine monitors successive weight records. If an animal shows a rapid weight drop of $\ge 8\%$, it triggers a high-priority **Parasitic Gastroenteritis** alert, instructing the farmer to administer a Broad-Spectrum Dewormer (Ivermectin).
*   **Geetha (KA-1989) Demo Case:** In the prefilled database, Geetha (KA-1989) is registered as a 4-year-old Hallikar breed located in Karnataka with a weight drop to 380 kg. This parameters trigger two simultaneous AI alerts:
    1.  **Parasitic Gastroenteritis (High Risk):** Due to the registered weight loss trend.
    2.  **Hemorrhagic Septicemia (High Risk):** Due to the location being in an endemic wet region (Karnataka).

---

## 8. How Can Another Person Reproduce / Deploy It?

1.  **Get the Source Code:** Clone or copy the folder `F:\Vaccination Monitoring\Vaccination Monitoring Code`.
2.  **Folder Layout:**
    *   `lib/core/theme/`: Visual themes.
    *   `lib/core/utils/`: PDF printer.
    *   `lib/features/vaccination_monitoring/data/`: Data models, repository, and services (AWS client, local database, notifications, and AI predictor engine).
    *   `lib/features/vaccination_monitoring/presentation/`: Dashboard view, reports, provider controller.
3.  **Cloud Setup:** Follow the steps in **Section 4.3** using the code in **[vaccinationMonitoringBackend.js](file:///f:/Vaccination%20Monitoring/User_manual/vaccinationMonitoringBackend.js)**.
4.  **Compile & Launch:** Run `flutter pub get` and `flutter run`.

---

## 9. Troubleshooting

### 9.1 Stuck on Loading Screen
*   **Cause:** The AWS API Gateway endpoint returned a `502 Bad Gateway` or `500` error, and the app failed to fallback, or the connection timed out.
*   **Fix:** Ensure you have updated the stream fallback logic in your repository. The fallback will show local mock data instead of spinning. Check your Lambda logs in CloudWatch.

### 9.2 HTTP 502 Bad Gateway
*   **Cause:** The Lambda function is throwing a permissions error or script syntax crash.
*   **Fix:** Under IAM, add the **`AmazonDynamoDBFullAccess`** policy to your Lambda execution role. Also, verify that the Node.js code does not use `require()` in an ES Module scope (`index.mjs` must use `import` syntax).

### 9.3 Device Not Detected (`flutter devices` is empty)
*   **Cause:** USB Debugging is not enabled, or Android USB drivers are missing on your computer.
*   **Fix:** Re-toggle USB Debugging on your phone. If on Windows, install the OEM USB Drivers or Google USB Driver via Android Studio SDK Manager.

### 9.4 AI Predictions Not Showing
*   **Cause:** The cattle record or reminder is not registered in the active provider list.
*   **Fix:** Ensure you have logged at least one vaccine entry or custom reminder. The AI predictor contains automatic fallback parameters (e.g. defaulting location to Karnataka and weight to 400kg) to ensure historical records still display alerts immediately.

---

## 10. Maintenance and Updates

### 10.1 Updating the App Code
To push updates, modify the Dart files inside the `lib/` directory, bump the version number in `pubspec.yaml` (line 19), and re-compile using:
```powershell
flutter build apk --debug
```

### 10.2 Database Backups
*   To back up vaccinations and reminders data, go to the **AWS Console > DynamoDB > Backups** and configure on-demand backups or scheduled daily backup rules.

### 10.3 Inspecting Logs
*   AWS transaction logs are accessible in **CloudWatch > Log groups > /aws/lambda/vaccinationMonitoringBackend**.

---

## 11. Version and Contact Information
*   **Project Version:** 1.1.0 (AI Predictions & Weight Integration Update)
*   **Release Date:** August 23, 2026
*   **Developer SDK versions:** Flutter 3.22.x, Dart 3.4.x, JDK 17, Node.js 24.x
*   **Repository Workspace:** `F:\Vaccination Monitoring\Vaccination Monitoring Code`
*   **Deployable Artifact:** `F:\Vaccination Monitoring\apk\vaccination_monitoring.apk`

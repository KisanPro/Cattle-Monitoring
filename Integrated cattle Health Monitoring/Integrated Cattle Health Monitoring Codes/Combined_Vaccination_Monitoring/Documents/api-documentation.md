# API Documentation

## REST APIs

### Get Vaccinations
- **Method**: `GET`
- **Path**: `/farmers/{farmerId}/vaccinations`
- **Purpose**: Retrieves all vaccination records for a specific farmer.
- **Request**: None (path parameter `farmerId`).
- **Response**:
  ```json
  [
    {
      "id": "vac_1787394340254",
      "farmerId": "farmer_kp_789",
      "cattleId": "AP 9999",
      "cattleName": "Shiva",
      "vaccineName": "Raksha HS",
      "vaccinationDate": "2026-08-22T00:00:00.000",
      "nextReminderDate": "2027-02-18T00:00:00.000",
      "status": "Completed",
      "isStarred": false
    }
  ]
  ```

### Add Vaccination Record
- **Method**: `POST`
- **Path**: `/farmers/{farmerId}/vaccinations`
- **Purpose**: Creates and saves a new vaccination record.
- **Request**:
  ```json
  {
    "cattleId": "AP 9999",
    "cattleName": "Shiva",
    "vaccineName": "Raksha HS",
    "vaccinationDate": "2026-08-22T00:00:00.000",
    "nextReminderDate": "2027-02-18T00:00:00.000",
    "status": "Completed"
  }
  ```
- **Response**: Returns the saved object with the generated `id` property.

### Get Reminders
- **Method**: `GET`
- **Path**: `/farmers/{farmerId}/reminders`
- **Purpose**: Fetches scheduled reminders.
- **Request**: None (path parameter `farmerId`).
- **Response**: List of Reminder items.

### Add Reminder
- **Method**: `POST`
- **Path**: `/farmers/{farmerId}/reminders`
- **Purpose**: Logs a new alert or alarm.
- **Request**:
  ```json
  {
    "vaccineName": "FMD Vaccine Boost",
    "reminderDate": "2026-09-22T00:00:00.000",
    "description": "Booster dose for Shiva (AP 9999)"
  }
  ```
- **Response**: Returns the saved item.

### Update Reminder Status
- **Method**: `PUT`
- **Path**: `/farmers/{farmerId}/reminders/{reminderId}`
- **Purpose**: Changes the status of an alert (e.g., marks it as completed).
- **Request**:
  ```json
  {
    "status": "Completed"
  }
  ```
- **Response**: `{"message": "Updated successfully"}`

---

## Internal APIs

### `VaccinationRepository` Class
*   `Stream<List<VaccinationModel>> getVaccinationsStream()`
    *   **Parameters**: None.
    *   **Return Type**: `Stream<List<VaccinationModel>>`. Returns active stream; redirects to Mock Database if AWS fails.
*   `Future<void> addVaccination(VaccinationModel vaccination)`
    *   **Parameters**: `VaccinationModel`.
    *   **Return Type**: `Future<void>`.
*   `Stream<List<ReminderModel>> getRemindersStream()`
    *   **Parameters**: None.
    *   **Return Type**: `Stream<List<ReminderModel>>`.
*   `Future<void> updateReminderStatus(String reminderId, String status)`
    *   **Parameters**: `String` ID, `String` status.
    *   **Return Type**: `Future<void>`.

---

## Data Models

### `VaccinationModel`
- **Fields**:
  - `id` (String): Unique identifier.
  - `cattleId` (String): Tag ID of the animal.
  - `cattleName` (String): Name of the animal.
  - `vaccineName` (String): Type of vaccine (e.g. FMD, Anthrax, Brucellosis).
  - `vaccinationDate` (DateTime): Date the dose was administered.
  - `nextReminderDate` (DateTime): Automated booster alarm date.
  - `status` (String): 'Completed' or 'Overdue'.
  - `isStarred` (bool): Stars important records.
- **Validation**:
  - All string inputs (cattleId, cattleName, vaccineName) must be non-empty.

### `ReminderModel`
- **Fields**:
  - `id` (String): Unique identifier.
  - `vaccineName` (String): Name of the target booster.
  - `reminderDate` (DateTime): Scheduled target alert date.
  - `description` (String): Detail details containing Cattle ID/Name.
  - `notificationSent` (bool): True if push alert has triggered.
  - `status` (String): 'Pending' or 'Completed'.

# API Documentation

## REST APIs
No REST APIs defined (embedded firmware module).

## Internal APIs
### Sensor Reading Interface
- **Functions**: 
  - `read_gps()` - Get GPS coordinates
  - `read_accelerometer()` - Get 3-axis acceleration data
  - `read_temperature()` - Get skin temperature

## Data Models
### GPS Data
- **Fields**: latitude, longitude, accuracy, timestamp
- **Relationships**: None

### Accelerometer Data
- **Fields**: x, y, z, timestamp
- **Relationships**: None

### Temperature Data
- **Fields**: temperature, unit, timestamp
- **Relationships**: None
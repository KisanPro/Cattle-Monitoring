import 'dart:math';

class GeofenceModel {
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final bool active;

  GeofenceModel({
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    this.active = true,
  });

  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    return GeofenceModel(
      centerLat: (json['center_latitude'] ?? json['center_lat'] ?? json['latitude'] ?? 13.308692).toDouble(),
      centerLon: (json['center_longitude'] ?? json['center_lon'] ?? json['longitude'] ?? 77.527069).toDouble(),
      radiusKm: (json['radius_km'] ?? json['radius'] ?? 0.5).toDouble(),
      active: json['active'] ?? true,
    );
  }

  // Calculate distance in kilometers using the Haversine formula
  double calculateDistanceKm(double lat, double lon) {
    if (lat == 0.0 || lon == 0.0) return 0.0;
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat - centerLat);
    double dLon = _degreesToRadians(lon - centerLon);

    double radLat1 = _degreesToRadians(centerLat);
    double radLat2 = _degreesToRadians(lat);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(radLat1) * cos(radLat2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  bool isBreached(double lat, double lon) {
    if (lat == 0.0 || lon == 0.0) return false;
    return calculateDistanceKm(lat, lon) > radiusKm;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}

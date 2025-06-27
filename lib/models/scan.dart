class Scan {
  final String id;
  final String animalId;
  final String userId;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  Scan({
    required this.id,
    required this.animalId,
    required this.userId,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });
}

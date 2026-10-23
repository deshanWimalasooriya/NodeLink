class LocationRecord {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String motionState; // 'STILL', 'WALKING', 'IN_VEHICLE', 'RUNNING'
  final int batteryLevel;
  final String address;

  const LocationRecord({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.motionState,
    required this.batteryLevel,
    required this.address,
  });
}

class NodeUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatarPath;
  final String? profilePicUrl;
  final String status; // 'Online', 'Active', 'Still', 'Offline'
  final bool isMoving;
  final int batteryLevel;
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;
  final bool isSelf;

  const NodeUser({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    required this.avatarPath,
    this.profilePicUrl,
    this.status = 'Active',
    this.isMoving = false,
    this.batteryLevel = 85,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    this.isSelf = false,
  });

  // Serialization strictly storing all details in Firebase Realtime Database
  Map<String, dynamic> toFirebaseJson() {
    return {
      'id': id,
      'nodeId': id,
      'name': name,
      'username': name,
      'email': email,
      'phone': phone,
      'phoneNumber': phone,
      'avatar': avatarPath,
      'profile_pic_url': profilePicUrl,
      'profilePicUrl': profilePicUrl ?? '',
      'status': status.toLowerCase() == 'online' ? 'online' : status,
      'is_moving': isMoving,
      'battery': batteryLevel,
      'location': {
        'lat': latitude,
        'lng': longitude,
        'timestamp': lastUpdated.millisecondsSinceEpoch,
      },
    };
  }

  factory NodeUser.fromFirebaseJson(String id, Map<dynamic, dynamic> json, {String? avatar, bool isSelf = false}) {
    final loc = json['location'] as Map<dynamic, dynamic>? ?? {};
    final lat = (loc['lat'] as num?)?.toDouble() ?? 6.9271;
    final lng = (loc['lng'] as num?)?.toDouble() ?? 79.8612;
    final timestamp = (loc['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

    final resolvedPhone = (json['phoneNumber'] as String?) ?? (json['phone'] as String?) ?? '';
    final resolvedName = (json['name'] as String?) ?? (json['username'] as String?) ?? 'Unknown Node';
    final resolvedId = (json['nodeId'] as String?) ?? (json['id'] as String?) ?? id;

    return NodeUser(
      id: resolvedId,
      name: resolvedName,
      email: (json['email'] as String?) ?? '',
      phone: resolvedPhone,
      avatarPath: (json['avatar'] as String?) ?? avatar ?? 'assets/avatars/alex.jpg',
      profilePicUrl: (json['profilePicUrl'] as String?) ?? (json['profile_pic_url'] as String?),
      status: (json['status'] as String?) ?? 'Active',
      isMoving: (json['is_moving'] as bool?) ?? false,
      batteryLevel: (json['battery'] as num?)?.toInt() ?? 85,
      latitude: lat,
      longitude: lng,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(timestamp),
      isSelf: isSelf,
    );
  }

  NodeUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarPath,
    String? profilePicUrl,
    String? status,
    bool? isMoving,
    int? batteryLevel,
    double? latitude,
    double? longitude,
    DateTime? lastUpdated,
    bool? isSelf,
  }) {
    return NodeUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      status: status ?? this.status,
      isMoving: isMoving ?? this.isMoving,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSelf: isSelf ?? this.isSelf,
    );
  }
}

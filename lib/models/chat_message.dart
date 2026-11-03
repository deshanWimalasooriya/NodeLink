class ChatMessage {
  final String id;
  final String peerNodeId;
  final String senderId;
  final String decryptedText;
  final String messageType; // text, image, video, voice, audio, location, document
  final String? mediaPath;
  final String? mediaDuration;
  final double? latitude;
  final double? longitude;
  final int timestamp;
  final String status; // sending, sent, delivered, read
  final bool isOutgoing;

  const ChatMessage({
    required this.id,
    required this.peerNodeId,
    required this.senderId,
    required this.decryptedText,
    this.messageType = 'text',
    this.mediaPath,
    this.mediaDuration,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.status = 'sent',
    required this.isOutgoing,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peerNodeId': peerNodeId,
      'senderId': senderId,
      'decryptedText': decryptedText,
      'messageType': messageType,
      'mediaPath': mediaPath,
      'mediaDuration': mediaDuration,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'status': status,
      'isOutgoing': isOutgoing ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String? ?? '',
      peerNodeId: map['peerNodeId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      decryptedText: map['decryptedText'] as String? ?? '',
      messageType: map['messageType'] as String? ?? 'text',
      mediaPath: map['mediaPath'] as String?,
      mediaDuration: map['mediaDuration'] as String?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      status: map['status'] as String? ?? 'sent',
      isOutgoing: (map['isOutgoing'] as int? ?? 1) == 1,
    );
  }

  /// JSON serialization for E2EE payload inside encrypted envelope
  Map<String, dynamic> toPayloadJson() {
    return {
      'id': id,
      'senderId': senderId,
      'decryptedText': decryptedText,
      'messageType': messageType,
      'mediaPath': mediaPath,
      'mediaDuration': mediaDuration,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromPayloadJson({
    required Map<String, dynamic> json,
    required String peerNodeId,
    required bool isOutgoing,
  }) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      peerNodeId: peerNodeId,
      senderId: json['senderId'] as String? ?? '',
      decryptedText: json['decryptedText'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'text',
      mediaPath: json['mediaPath'] as String?,
      mediaDuration: json['mediaDuration'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      status: 'delivered',
      isOutgoing: isOutgoing,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? peerNodeId,
    String? senderId,
    String? decryptedText,
    String? messageType,
    String? mediaPath,
    String? mediaDuration,
    double? latitude,
    double? longitude,
    int? timestamp,
    String? status,
    bool? isOutgoing,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      peerNodeId: peerNodeId ?? this.peerNodeId,
      senderId: senderId ?? this.senderId,
      decryptedText: decryptedText ?? this.decryptedText,
      messageType: messageType ?? this.messageType,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }
}

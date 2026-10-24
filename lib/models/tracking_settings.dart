class TrackingSettings {
  final int activeIntervalSec; // e.g. 30, 60 (1 min), 300 (5 mins)
  final int sleepIntervalSec;  // e.g. 300 (5 mins), 600 (10 mins), 1200 (20 mins)
  final bool lowBatterySaver;  // Throttle to 20 mins when <15%
  final bool nodeLinkRequestAlerts;
  final bool liveUpdatesAlerts;
  final bool serviceRunningNotification;
  final String mapDisplayStyle;
  final bool profilePicsOnPins;
  final bool visibleToConnectionOnly;
  final bool biometricLock;
  final bool alwaysShareLocation;
  final String firebaseDbUrl;

  static const String defaultDbUrl =
      'https://nodelink-5232f-default-rtdb.asia-southeast1.firebasedatabase.app';

  const TrackingSettings({
    this.activeIntervalSec = 60, // 1 Min default for ACTIVE
    this.sleepIntervalSec = 600, // 10 Mins default for STILL
    this.lowBatterySaver = true,
    this.nodeLinkRequestAlerts = true,
    this.liveUpdatesAlerts = true,
    this.serviceRunningNotification = true,
    this.mapDisplayStyle = 'Cyber-Dark Mode',
    this.profilePicsOnPins = true,
    this.visibleToConnectionOnly = true,
    this.biometricLock = false,
    this.alwaysShareLocation = true,
    this.firebaseDbUrl = defaultDbUrl,
  });

  TrackingSettings copyWith({
    int? activeIntervalSec,
    int? sleepIntervalSec,
    bool? lowBatterySaver,
    bool? nodeLinkRequestAlerts,
    bool? liveUpdatesAlerts,
    bool? serviceRunningNotification,
    String? mapDisplayStyle,
    bool? profilePicsOnPins,
    bool? visibleToConnectionOnly,
    bool? biometricLock,
    bool? alwaysShareLocation,
    String? firebaseDbUrl,
  }) {
    return TrackingSettings(
      activeIntervalSec: activeIntervalSec ?? this.activeIntervalSec,
      sleepIntervalSec: sleepIntervalSec ?? this.sleepIntervalSec,
      lowBatterySaver: lowBatterySaver ?? this.lowBatterySaver,
      nodeLinkRequestAlerts: nodeLinkRequestAlerts ?? this.nodeLinkRequestAlerts,
      liveUpdatesAlerts: liveUpdatesAlerts ?? this.liveUpdatesAlerts,
      serviceRunningNotification: serviceRunningNotification ?? this.serviceRunningNotification,
      mapDisplayStyle: mapDisplayStyle ?? this.mapDisplayStyle,
      profilePicsOnPins: profilePicsOnPins ?? this.profilePicsOnPins,
      visibleToConnectionOnly: visibleToConnectionOnly ?? this.visibleToConnectionOnly,
      biometricLock: biometricLock ?? this.biometricLock,
      alwaysShareLocation: alwaysShareLocation ?? this.alwaysShareLocation,
      firebaseDbUrl: firebaseDbUrl ?? this.firebaseDbUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'activeIntervalSec': activeIntervalSec,
    'sleepIntervalSec': sleepIntervalSec,
    'lowBatterySaver': lowBatterySaver,
    'nodeLinkRequestAlerts': nodeLinkRequestAlerts,
    'liveUpdatesAlerts': liveUpdatesAlerts,
    'serviceRunningNotification': serviceRunningNotification,
    'mapDisplayStyle': mapDisplayStyle,
    'profilePicsOnPins': profilePicsOnPins,
    'visibleToConnectionOnly': visibleToConnectionOnly,
    'biometricLock': biometricLock,
    'alwaysShareLocation': alwaysShareLocation,
    'firebaseDbUrl': firebaseDbUrl,
  };

  factory TrackingSettings.fromJson(Map<String, dynamic> json) {
    final rawDbUrl = json['firebaseDbUrl'] as String?;
    return TrackingSettings(
      activeIntervalSec: json['activeIntervalSec'] as int? ?? 60,
      sleepIntervalSec: json['sleepIntervalSec'] as int? ?? 600,
      lowBatterySaver: json['lowBatterySaver'] as bool? ?? true,
      nodeLinkRequestAlerts: json['nodeLinkRequestAlerts'] as bool? ?? true,
      liveUpdatesAlerts: json['liveUpdatesAlerts'] as bool? ?? true,
      serviceRunningNotification: json['serviceRunningNotification'] as bool? ?? true,
      mapDisplayStyle: json['mapDisplayStyle'] as String? ?? 'Cyber-Dark Mode',
      profilePicsOnPins: json['profilePicsOnPins'] as bool? ?? true,
      visibleToConnectionOnly: json['visibleToConnectionOnly'] as bool? ?? true,
      biometricLock: json['biometricLock'] as bool? ?? false,
      alwaysShareLocation: json['alwaysShareLocation'] as bool? ?? true,
      firebaseDbUrl: (rawDbUrl != null && rawDbUrl.trim().isNotEmpty)
          ? rawDbUrl.trim()
          : defaultDbUrl,
    );
  }
}

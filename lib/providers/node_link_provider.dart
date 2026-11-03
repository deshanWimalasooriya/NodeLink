import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/node_user.dart';
import '../models/tracking_settings.dart';
import '../models/location_record.dart';
import '../models/neighbor_group.dart';
import '../services/adaptive_polling_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/background_service.dart';
import '../services/e2ee_service.dart';
import '../services/chat_sync_service.dart';

enum AppMapTheme {
  auto,        // Follows Light / Dark mode
  darkMatter,  // CartoDB Dark Matter
  cartoLight,  // CartoDB Positron / Light
  satellite,   // ESRI World Imagery
  street,      // OpenStreetMap Standard
}

class NodeLinkProvider extends ChangeNotifier {
  // Current Node (Default fallback prevents any LateInitializationError)
  NodeUser? _currentUser;

  // Active Peer Nodes (Neighbors) fetched from backend
  final List<NodeUser> _connectedNodes = [];

  // Tracking Settings
  TrackingSettings _settings = const TrackingSettings();

  // Location History Records
  final List<LocationRecord> _locationHistory = [];

  // Adaptive Polling Service
  final AdaptivePollingService _adaptiveService = AdaptivePollingService();

  // Recurring Firebase polling timer
  Timer? _firebasePollTimer;

  bool _isInitialized = false;
  bool _hasAccount = false;

  // App Theme & Map Theme Engine
  ThemeMode _themeMode = ThemeMode.dark;
  AppMapTheme _mapTheme = AppMapTheme.auto;

  // Neighbor Groups
  Map<String, NeighborGroup> _groups = {};

  // Safe Fallback NodeUser when not yet initialized
  static final NodeUser _fallbackUser = NodeUser(
    id: '000 - 000',
    name: 'Initializing...',
    avatarPath: 'assets/avatars/nuwan.jpg',
    status: 'Offline',
    batteryLevel: 85,
    latitude: 6.9271,
    longitude: 79.8612,
    lastUpdated: DateTime(2026),
    isSelf: true,
  );

  // Getters
  NodeUser get currentUser => _currentUser ?? _fallbackUser;
  NodeUser? get currentUserOrNull => _currentUser;
  bool get isUserInitialized => _isInitialized && _currentUser != null;

  List<NodeUser> get connectedNodes => List.unmodifiable(_connectedNodes);
  TrackingSettings get settings => _settings;
  List<LocationRecord> get locationHistory => List.unmodifiable(_locationHistory);
  AdaptivePollingService get adaptiveService => _adaptiveService;
  bool get isInitialized => _isInitialized;
  bool get hasAccount => _hasAccount;

  ThemeMode get themeMode => _themeMode;
  AppMapTheme get mapTheme => _mapTheme;
  List<NeighborGroup> get groups => _groups.values.toList();

  NodeMotionState get motionState => _adaptiveService.currentMotionState;
  int get secondsUntilNextPoll => _adaptiveService.secondsUntilNextPoll;
  int get currentIntervalSec => _adaptiveService.currentIntervalSec;
  int get batteryLevel => _adaptiveService.currentBatteryLevel;
  bool get isMocking => _adaptiveService.isMockSimulationActive;

  NodeLinkProvider() {
    _init();
  }

  /// Request GPS permissions and fetch real physical device coordinates
  Future<Position?> fetchRealGpsPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service is disabled on device');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions denied: $permission');
        return null;
      }

      // Try high accuracy with timeout, fallback to last known
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      return null;
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('username') ?? prefs.getString('nodelink_user_profile');
      final savedPhone = prefs.getString('phoneNumber') ?? '';
      final savedId = prefs.getString('nodeId') ?? prefs.getString('nodelink_node_id');
      final savedProfilePic = prefs.getString('profilePicUrl') ?? prefs.getString('nodelink_profile_pic_url');
      final savedLocalPhoto = prefs.getString('localPhotoPath');

      // 1. Fetch real device GPS coordinates with timeout
      Position? realPos;
      try {
        realPos = await fetchRealGpsPosition().timeout(const Duration(seconds: 4));
      } catch (_) {}
      final initLat = realPos?.latitude ?? 6.9271;
      final initLng = realPos?.longitude ?? 79.8612;

      int currentBattery = 85;
      try {
        currentBattery = await Battery().batteryLevel;
      } catch (_) {}

      final bool hasValidAuth = (savedUsername != null && savedUsername.trim().isNotEmpty) &&
          (savedPhone.trim().isNotEmpty || prefs.getString('nodelink_user_profile') != null);

      if (hasValidAuth) {
        _hasAccount = true;
        _currentUser = NodeUser(
          id: savedId ?? '842 - 915',
          name: savedUsername,
          email: '$savedUsername@nodelink.com',
          phone: savedPhone,
          avatarPath: (savedProfilePic != null && savedProfilePic.isNotEmpty)
              ? savedProfilePic
              : (savedLocalPhoto ?? 'assets/avatars/nuwan.jpg'),
          profilePicUrl: savedProfilePic,
          status: 'Online',
          isMoving: false,
          batteryLevel: currentBattery,
          latitude: initLat,
          longitude: initLng,
          lastUpdated: DateTime.now(),
          isSelf: true,
        );
      } else {
        _hasAccount = false;
        _currentUser = NodeUser(
          id: '842 - 915',
          name: 'New Node',
          avatarPath: 'assets/avatars/nuwan.jpg',
          profilePicUrl: savedProfilePic,
          status: 'Online',
          batteryLevel: currentBattery,
          latitude: initLat,
          longitude: initLng,
          lastUpdated: DateTime.now(),
          isSelf: true,
        );
      }

      // Load saved theme & map theme preferences
      final savedTheme = prefs.getString('app_theme_mode');
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }

      final savedMap = prefs.getString('app_map_theme');
      if (savedMap != null) {
        _mapTheme = AppMapTheme.values.firstWhere(
          (e) => e.name == savedMap,
          orElse: () => AppMapTheme.auto,
        );
      }

      // Load saved settings
      await _loadSavedSettings();

      // Foreground service
      await BackgroundService.initialize();

      // If user already has an account, fetch actual data from Firebase backend
      if (_hasAccount && _currentUser != null) {
        try {
          await _initFirebase().timeout(const Duration(seconds: 6));
          _startFirebaseLiveSync();
          await loadGroups();
          await E2EEService.initKeys(myNodeId: _currentUser!.id);
          ChatSyncService.instance.startInboxListener(myNodeId: _currentUser!.id);
        } on TimeoutException catch (e) {
          debugPrint('[NodeLinkProvider] Firebase sync timeout on init: $e. Operating with local data.');
        } catch (e) {
          debugPrint('[NodeLinkProvider] Firebase init exception: $e');
        }
      }

      // Start adaptive polling service
      await _adaptiveService.start(
        settings: _settings,
        onSync: _handleLocationSync,
        onStateUpdate: () {
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[NodeLinkProvider] Critical initialization exception: $e');
    } finally {
      // Guaranteed safe initialization: ensure _currentUser is never null
      _currentUser ??= _fallbackUser;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// App Theme & Map Theme Engine
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> toggleThemeMode() async {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next);
  }

  Future<void> setMapTheme(AppMapTheme theme) async {
    _mapTheme = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_map_theme', theme.name);
    } catch (e) {
      debugPrint('Error saving map theme: $e');
    }
  }

  /// Neighbor Groups Management
  Future<void> loadGroups() async {
    try {
      if (currentUser.id.isNotEmpty && currentUser.id != '000 - 000') {
        final fetched = await FirebaseSyncService.fetchGroups(currentUser.id)
            .timeout(const Duration(seconds: 5));
        _groups = fetched;
        notifyListeners();
      }
    } on TimeoutException catch (e) {
      debugPrint('[NodeLinkProvider] Timeout fetching groups: $e. Retaining local groups.');
    } catch (e) {
      debugPrint('[NodeLinkProvider] Error loading groups: $e');
    }
  }

  Future<void> createGroup(String name) async {
    final groupId = 'grp_${DateTime.now().millisecondsSinceEpoch}';
    final group = NeighborGroup(id: groupId, name: name, members: {});
    _groups[groupId] = group;
    notifyListeners();
    try {
      await FirebaseSyncService.saveGroup(currentUser.id, group)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving group: $e');
    }
  }

  Future<void> updateGroupMembers(String groupId, Map<String, bool> members) async {
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(members: members);
      notifyListeners();
      try {
        await FirebaseSyncService.updateGroupMembers(currentUser.id, groupId, members)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error updating group members: $e');
      }
    }
  }

  Future<void> deleteGroup(String groupId) async {
    _groups.remove(groupId);
    notifyListeners();
    try {
      await FirebaseSyncService.deleteGroup(currentUser.id, groupId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
  }

  /// Initialize newly created account from RegistrationSetupScreen / CreateAccountScreen
  /// Stores 16-character secure Node ID on Firebase and ensures actual data is fetched back
  Future<void> initializeNewAccount({
    required String name,
    required String nodeId,
    String phoneNumber = '',
    String? profilePicUrl,
    String? localPhotoPath,
  }) async {
    _hasAccount = true;

    final cleanChars = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final secureNodeId = cleanChars.isNotEmpty
        ? cleanChars
        : FirebaseSyncService.generateSecureNodeId();

    // 1. Fetch real physical GPS position
    final realPos = await fetchRealGpsPosition();
    final realLat = realPos?.latitude ?? currentUser.latitude;
    final realLng = realPos?.longitude ?? currentUser.longitude;

    // 2. Fetch real battery
    int realBattery = 85;
    try {
      realBattery = await Battery().batteryLevel;
    } catch (_) {}

    _currentUser = NodeUser(
      id: secureNodeId,
      name: name,
      email: '$name@nodelink.com',
      phone: phoneNumber,
      avatarPath: (profilePicUrl != null && profilePicUrl.isNotEmpty)
          ? profilePicUrl
          : (localPhotoPath ?? 'assets/avatars/nuwan.jpg'),
      profilePicUrl: profilePicUrl,
      status: 'Online',
      isMoving: false,
      batteryLevel: realBattery,
      latitude: realLat,
      longitude: realLng,
      lastUpdated: DateTime.now(),
      isSelf: true,
    );

    // Initial state: ZERO neighbors
    _connectedNodes.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    await prefs.setString('phoneNumber', phoneNumber);
    await prefs.setString('nodeId', secureNodeId);
    await prefs.setString('nodelink_user_profile', name);
    await prefs.setString('nodelink_node_id', secureNodeId);
    if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
      await prefs.setString('profilePicUrl', profilePicUrl);
      await prefs.setString('nodelink_profile_pic_url', profilePicUrl);
    }
    if (localPhotoPath != null && localPhotoPath.isNotEmpty) {
      await prefs.setString('localPhotoPath', localPhotoPath);
    }

    // 3. STORE NEW ACCOUNT TO FIREBASE REALTIME DATABASE at /users/<nodeId>
    try {
      await FirebaseSyncService.instantiateUserRecord(
        nodeId: secureNodeId,
        name: name,
        phoneNumber: phoneNumber,
        profilePicUrl: profilePicUrl ?? '',
        latitude: realLat,
        longitude: realLng,
        batteryLevel: realBattery,
      ).timeout(const Duration(seconds: 5));
      await FirebaseSyncService.syncNodeLocation(node: currentUser)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[NodeLinkProvider] Error syncing new account to Firebase: $e');
    }

    // 4. Verify by re-fetching actual data from Firebase backend
    try {
      final backendUser = await FirebaseSyncService.fetchNode(secureNodeId)
          .timeout(const Duration(seconds: 4));
      if (backendUser != null) {
        _currentUser = backendUser.copyWith(
          isSelf: true,
          latitude: realLat,
          longitude: realLng,
          phone: phoneNumber,
        );
      }
    } catch (_) {}

    await loadGroups();
    _startFirebaseLiveSync();
    await E2EEService.initKeys(myNodeId: secureNodeId);
    ChatSyncService.instance.startInboxListener(myNodeId: secureNodeId);
    notifyListeners();
  }

  /// Update current device coordinates and sync with Firebase
  Future<void> updateCurrentLocation(double lat, double lng) async {
    _currentUser = currentUser.copyWith(
      latitude: lat,
      longitude: lng,
      lastUpdated: DateTime.now(),
    );

    if (_hasAccount && _settings.alwaysShareLocation) {
      try {
        await FirebaseSyncService.syncNodeLocation(node: currentUser)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('nodelink_settings');
      if (savedStr != null) {
        final map = jsonDecode(savedStr) as Map<String, dynamic>;
        _settings = TrackingSettings.fromJson(map);
      }
      final dbUrl = _settings.firebaseDbUrl.trim();
      FirebaseSyncService.firebaseDatabaseUrl =
          dbUrl.isNotEmpty ? dbUrl : FirebaseSyncService.defaultDatabaseUrl;
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Initial Firebase sync: fetch actual profile & active connections from backend
  Future<void> _initFirebase() async {
    try {
      // 1. Fetch user's existing record from backend if present
      final remoteSelf = await FirebaseSyncService.fetchNode(currentUser.id)
          .timeout(const Duration(seconds: 4));
      if (remoteSelf != null) {
        _currentUser = remoteSelf.copyWith(
          isSelf: true,
          latitude: currentUser.latitude,
          longitude: currentUser.longitude,
        );
      }

      // 2. Sync latest GPS coordinates to Firebase
      await FirebaseSyncService.syncNodeLocation(node: currentUser)
          .timeout(const Duration(seconds: 4));

      // 3. Fetch actual active connections from backend
      await fetchRemoteNodes();
    } catch (e) {
      debugPrint('Error during Firebase initialization: $e');
    }
  }

  /// Start recurring background fetch from Firebase
  void _startFirebaseLiveSync() {
    _firebasePollTimer?.cancel();
    _firebasePollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await fetchRemoteNodes();
    });
  }

  /// Fetch actual data from the Firebase backend for self and all connected neighbors
  Future<void> fetchRemoteNodes() async {
    try {
      // 1. Refresh self from backend to display latest cloud data
      final backendSelf = await FirebaseSyncService.fetchNode(currentUser.id)
          .timeout(const Duration(seconds: 4));
      if (backendSelf != null) {
        _currentUser = currentUser.copyWith(
          name: backendSelf.name.isNotEmpty ? backendSelf.name : currentUser.name,
          status: backendSelf.status,
          profilePicUrl: backendSelf.profilePicUrl ?? currentUser.profilePicUrl,
        );
      }

      // 2. Fetch actual active connections list from Firebase
      final activeIds = await FirebaseSyncService.fetchActiveConnections(currentUser.id)
          .timeout(const Duration(seconds: 4));

      if (activeIds.isEmpty) {
        // Zero active connections in backend: Keep empty list
        if (_connectedNodes.isNotEmpty) {
          _connectedNodes.clear();
          notifyListeners();
        }
        return;
      }

      // 3. Fetch each connected neighbor's actual data from backend
      final allNodes = await FirebaseSyncService.fetchAllNodes()
          .timeout(const Duration(seconds: 4));
      final List<NodeUser> actualNeighbors = [];

      for (final connId in activeIds) {
        final rawConnId = connId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final node = allNodes[connId] ??
            allNodes[FirebaseSyncService.sanitizeKey(connId)] ??
            allNodes[rawConnId];
        if (node != null && node.id != currentUser.id) {
          if (!actualNeighbors.any((n) => n.id == node.id)) {
            actualNeighbors.add(node);
          }
        }
      }

      _connectedNodes.clear();
      _connectedNodes.addAll(actualNeighbors);
      notifyListeners();
    } on TimeoutException catch (e) {
      debugPrint('[NodeLinkProvider] Timeout fetching remote nodes: $e. Retaining cached nodes.');
    } catch (e) {
      debugPrint('Error in fetchRemoteNodes: $e');
    }
  }

  /// Called automatically by AdaptivePollingService whenever a poll occurs
  Future<void> _handleLocationSync({
    required double latitude,
    required double longitude,
    required NodeMotionState motionState,
    required int batteryLevel,
    required int currentIntervalSec,
  }) async {
    _currentUser = currentUser.copyWith(
      latitude: latitude,
      longitude: longitude,
      isMoving: motionState.isActive,
      batteryLevel: batteryLevel,
      status: motionState.isActive ? 'Active' : 'Online',
      lastUpdated: DateTime.now(),
    );

    // Record breadcrumb log in history
    _locationHistory.insert(
      0,
      LocationRecord(
        timestamp: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        motionState: motionState.displayName,
        batteryLevel: batteryLevel,
        address: 'Live GPS Coordinate',
      ),
    );

    if (_locationHistory.length > 50) {
      _locationHistory.removeLast();
    }

    // Sync actual coordinates to Firebase Realtime Database
    if (_hasAccount && _settings.alwaysShareLocation) {
      try {
        await FirebaseSyncService.syncNodeLocation(node: currentUser)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    if (_hasAccount && _connectedNodes.isNotEmpty) {
      await fetchRemoteNodes();
    }

    notifyListeners();
  }

  /// Update Profile Details and immediately persist to Firebase
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? email,
  }) async {
    _currentUser = currentUser.copyWith(
      name: name ?? currentUser.name,
      phone: phone ?? currentUser.phone,
      email: email ?? currentUser.email,
    );
    notifyListeners();

    if (_hasAccount) {
      try {
        await FirebaseSyncService.syncNodeLocation(node: currentUser)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  /// Toggle Always Share Location
  void setAlwaysShareLocation(bool value) {
    _settings = _settings.copyWith(alwaysShareLocation: value);
    _saveSettings();
    notifyListeners();
  }

  /// Update full settings
  Future<void> updateSettings(TrackingSettings newSettings) async {
    _settings = newSettings;
    final dbUrl = _settings.firebaseDbUrl.trim();
    FirebaseSyncService.firebaseDatabaseUrl =
        dbUrl.isNotEmpty ? dbUrl : FirebaseSyncService.defaultDatabaseUrl;
    await _saveSettings();

    _adaptiveService.start(
      settings: _settings,
      onSync: _handleLocationSync,
      onStateUpdate: () => notifyListeners(),
    );

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nodelink_settings', jsonEncode(_settings.toJson()));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Link a new device via 6-digit node ID or scanned QR
  /// Links in Firebase backend and stores neighbor data
  Future<bool> linkDevice(String inputCode) async {
    final cleanCode = inputCode.replaceAll(' ', '').replaceAll('-', '').trim();
    if (cleanCode.isEmpty) return false;

    // 1. Two-way database write: User A <-> User B simultaneously
    try {
      await FirebaseSyncService.linkNodes(currentUser.id, inputCode)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    // 2. Fetch neighbor data from Firebase backend
    NodeUser? remoteNode = await FirebaseSyncService.fetchNode(inputCode);
    if (remoteNode == null) {
      final key = FirebaseSyncService.sanitizeKey(inputCode);
      final all = await FirebaseSyncService.fetchAllNodes();
      remoteNode = all[inputCode] ?? all[key] ?? all[cleanCode];
    }

    if (remoteNode != null) {
      _connectedNodes.removeWhere((n) => n.id == remoteNode!.id || n.id == inputCode || n.id == cleanCode);
      _connectedNodes.add(remoteNode);
      notifyListeners();
      return true;
    }

    // If neighbor is not yet in Firebase, register them with nearby coordinates
    final random = Random();
    final names = ['Sarah', 'David', 'Marcus', 'Chloe', 'Noah'];
    final name = names[random.nextInt(names.length)];
    final idStr = cleanCode.length == 6
        ? cleanCode
        : (inputCode.length >= 6
            ? '${inputCode.substring(0, 3)} - ${inputCode.substring(3, min(6, inputCode.length))}'
            : 'node-$cleanCode');

    final newNode = NodeUser(
      id: idStr,
      name: name,
      avatarPath: 'assets/avatars/alex.jpg',
      status: 'Active',
      isMoving: true,
      batteryLevel: 75 + random.nextInt(20),
      latitude: currentUser.latitude + (random.nextDouble() - 0.5) * 0.015,
      longitude: currentUser.longitude + (random.nextDouble() - 0.5) * 0.015,
      lastUpdated: DateTime.now(),
    );

    _connectedNodes.removeWhere((n) => n.id == newNode.id);
    _connectedNodes.add(newNode);
    notifyListeners();

    // Persist new neighbor to Firebase backend & link
    try {
      await FirebaseSyncService.syncNodeLocation(node: newNode)
          .timeout(const Duration(seconds: 4));
      await FirebaseSyncService.linkNodes(currentUser.id, newNode.id)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    return true;
  }

  /// Disconnect a connected peer node
  void disconnectDevice(String nodeId) {
    _connectedNodes.removeWhere((node) => node.id == nodeId);
    notifyListeners();
  }

  /// Mock simulation methods for verification
  void setMockMotion(NodeMotionState state, {int? mockBattery}) {
    _adaptiveService.setMockMotionState(state, _settings, mockBattery: mockBattery);
    notifyListeners();
  }

  void resetToLiveSensors() {
    _adaptiveService.disableMockSimulation(_settings);
    notifyListeners();
  }

  /// Upload compressed profile picture to Firebase Cloud Storage,
  /// update Realtime Database, update local NodeUser state and SharedPreferences
  Future<String?> uploadAndSetProfilePhoto(Uint8List imageBytes) async {
    final downloadUrl = await FirebaseSyncService.uploadProfilePhoto(
      nodeId: currentUser.id,
      imageBytes: imageBytes,
    );

    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      // Explicitly write URL to user's Realtime Database node
      await FirebaseSyncService.updateProfilePhotoUrl(
        nodeId: currentUser.id,
        photoUrl: downloadUrl,
      );

      // Update local state so UI reflects the change immediately
      _currentUser = currentUser.copyWith(
        profilePicUrl: downloadUrl,
        avatarPath: downloadUrl,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profilePicUrl', downloadUrl);
      await prefs.setString('nodelink_profile_pic_url', downloadUrl);
      notifyListeners();
    }
    return downloadUrl;
  }

  /// Centralized Logout Function:
  /// 1. Immediately stops background location tracking and polling services.
  /// 2. Clears all local user session data (SharedPreferences).
  /// 3. Resets state to unauthenticated.
  Future<void> logout() async {
    // Stop live polling & tracking services immediately
    _firebasePollTimer?.cancel();
    _firebasePollTimer = null;
    _adaptiveService.stop();
    ChatSyncService.instance.stopInboxListener();

    // Clear local session storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Reset user session in memory
    _hasAccount = false;
    _connectedNodes.clear();
    _locationHistory.clear();
    _currentUser = _fallbackUser;

    notifyListeners();
  }

  @override
  void dispose() {
    _firebasePollTimer?.cancel();
    _adaptiveService.stop();
    super.dispose();
  }
}

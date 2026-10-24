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
import '../services/adaptive_polling_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/background_service.dart';

class NodeLinkProvider extends ChangeNotifier {
  // Current Node
  late NodeUser _currentUser;

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

  // Getters
  NodeUser get currentUser => _currentUser;
  List<NodeUser> get connectedNodes => List.unmodifiable(_connectedNodes);
  TrackingSettings get settings => _settings;
  List<LocationRecord> get locationHistory => List.unmodifiable(_locationHistory);
  AdaptivePollingService get adaptiveService => _adaptiveService;
  bool get isInitialized => _isInitialized;
  bool get hasAccount => _hasAccount;

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
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username') ?? prefs.getString('nodelink_user_profile');
    final savedPhone = prefs.getString('phoneNumber') ?? '';
    final savedId = prefs.getString('nodeId') ?? prefs.getString('nodelink_node_id');
    final savedProfilePic = prefs.getString('profilePicUrl') ?? prefs.getString('nodelink_profile_pic_url');
    final savedLocalPhoto = prefs.getString('localPhotoPath');

    // 1. Fetch real device GPS coordinates
    final realPos = await fetchRealGpsPosition();
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

    // Load saved settings
    await _loadSavedSettings();

    // Foreground service
    await BackgroundService.initialize();

    // If user already has an account, fetch actual data from Firebase backend
    if (_hasAccount) {
      await _initFirebase();
      _startFirebaseLiveSync();
    }

    // Start adaptive polling service
    await _adaptiveService.start(
      settings: _settings,
      onSync: _handleLocationSync,
      onStateUpdate: () {
        notifyListeners();
      },
    );

    _isInitialized = true;
    notifyListeners();
  }

  /// Initialize newly created account from RegistrationSetupScreen / CreateAccountScreen
  /// Stores user on Firebase and ensures actual data is fetched back
  Future<void> initializeNewAccount({
    required String name,
    required String nodeId,
    String phoneNumber = '',
    String? profilePicUrl,
    String? localPhotoPath,
  }) async {
    _hasAccount = true;

    final cleanDigits = nodeId.replaceAll(RegExp(r'[^0-9]'), '');
    final persistent6DigitId = cleanDigits.length >= 6
        ? cleanDigits.substring(0, 6)
        : (cleanDigits.isNotEmpty ? cleanDigits : nodeId);

    // 1. Fetch real physical GPS position
    final realPos = await fetchRealGpsPosition();
    final realLat = realPos?.latitude ?? _currentUser.latitude;
    final realLng = realPos?.longitude ?? _currentUser.longitude;

    // 2. Fetch real battery
    int realBattery = 85;
    try {
      realBattery = await Battery().batteryLevel;
    } catch (_) {}

    _currentUser = NodeUser(
      id: persistent6DigitId,
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
    await prefs.setString('nodeId', persistent6DigitId);
    await prefs.setString('nodelink_user_profile', name);
    await prefs.setString('nodelink_node_id', persistent6DigitId);
    if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
      await prefs.setString('profilePicUrl', profilePicUrl);
      await prefs.setString('nodelink_profile_pic_url', profilePicUrl);
    }
    if (localPhotoPath != null && localPhotoPath.isNotEmpty) {
      await prefs.setString('localPhotoPath', localPhotoPath);
    }

    // 3. STORE NEW ACCOUNT TO FIREBASE REALTIME DATABASE at /users/<nodeId>
    await FirebaseSyncService.instantiateUserRecord(
      nodeId: persistent6DigitId,
      name: name,
      phoneNumber: phoneNumber,
      profilePicUrl: profilePicUrl ?? '',
      latitude: realLat,
      longitude: realLng,
      batteryLevel: realBattery,
    );
    await FirebaseSyncService.syncNodeLocation(node: _currentUser);

    // 4. Verify by re-fetching actual data from Firebase backend
    final backendUser = await FirebaseSyncService.fetchNode(persistent6DigitId);
    if (backendUser != null) {
      _currentUser = backendUser.copyWith(
        isSelf: true,
        latitude: realLat,
        longitude: realLng,
        phone: phoneNumber,
      );
    }

    // Start live cloud synchronization
    _startFirebaseLiveSync();

    notifyListeners();
  }

  /// Update current device coordinates and sync with Firebase
  Future<void> updateCurrentLocation(double lat, double lng) async {
    _currentUser = _currentUser.copyWith(
      latitude: lat,
      longitude: lng,
      lastUpdated: DateTime.now(),
    );

    if (_hasAccount && _settings.alwaysShareLocation) {
      await FirebaseSyncService.syncNodeLocation(node: _currentUser);
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
      FirebaseSyncService.firebaseDatabaseUrl = _settings.firebaseDbUrl;
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Initial Firebase sync: fetch actual profile & active connections from backend
  Future<void> _initFirebase() async {
    try {
      // 1. Fetch user's existing record from backend if present
      final remoteSelf = await FirebaseSyncService.fetchNode(_currentUser.id);
      if (remoteSelf != null) {
        _currentUser = remoteSelf.copyWith(
          isSelf: true,
          latitude: _currentUser.latitude,
          longitude: _currentUser.longitude,
        );
      }

      // 2. Sync latest GPS coordinates to Firebase
      await FirebaseSyncService.syncNodeLocation(node: _currentUser);

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
      final backendSelf = await FirebaseSyncService.fetchNode(_currentUser.id);
      if (backendSelf != null) {
        _currentUser = _currentUser.copyWith(
          name: backendSelf.name.isNotEmpty ? backendSelf.name : _currentUser.name,
          status: backendSelf.status,
          profilePicUrl: backendSelf.profilePicUrl ?? _currentUser.profilePicUrl,
        );
      }

      // 2. Fetch actual active connections list from Firebase
      final activeIds = await FirebaseSyncService.fetchActiveConnections(_currentUser.id);

      if (activeIds.isEmpty) {
        // Zero active connections in backend: Keep empty list
        if (_connectedNodes.isNotEmpty) {
          _connectedNodes.clear();
          notifyListeners();
        }
        return;
      }

      // 3. Fetch each connected neighbor's actual data from backend
      final allNodes = await FirebaseSyncService.fetchAllNodes();
      final List<NodeUser> actualNeighbors = [];

      for (final connId in activeIds) {
        final rawConnId = connId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final node = allNodes[connId] ??
            allNodes[FirebaseSyncService.sanitizeKey(connId)] ??
            allNodes[rawConnId];
        if (node != null && node.id != _currentUser.id) {
          if (!actualNeighbors.any((n) => n.id == node.id)) {
            actualNeighbors.add(node);
          }
        }
      }

      _connectedNodes.clear();
      _connectedNodes.addAll(actualNeighbors);
      notifyListeners();
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
    _currentUser = _currentUser.copyWith(
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
      await FirebaseSyncService.syncNodeLocation(node: _currentUser);
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
    _currentUser = _currentUser.copyWith(
      name: name ?? _currentUser.name,
      phone: phone ?? _currentUser.phone,
      email: email ?? _currentUser.email,
    );
    notifyListeners();

    if (_hasAccount) {
      await FirebaseSyncService.syncNodeLocation(node: _currentUser);
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
    FirebaseSyncService.firebaseDatabaseUrl = _settings.firebaseDbUrl;
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
    await FirebaseSyncService.linkNodes(_currentUser.id, inputCode);

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
      latitude: _currentUser.latitude + (random.nextDouble() - 0.5) * 0.015,
      longitude: _currentUser.longitude + (random.nextDouble() - 0.5) * 0.015,
      lastUpdated: DateTime.now(),
    );

    _connectedNodes.removeWhere((n) => n.id == newNode.id);
    _connectedNodes.add(newNode);
    notifyListeners();

    // Persist new neighbor to Firebase backend & link
    await FirebaseSyncService.syncNodeLocation(node: newNode);
    await FirebaseSyncService.linkNodes(_currentUser.id, newNode.id);

    return true;
  }

  /// Disconnect a connected peer node
  void disconnectDevice(String nodeId) {
    _connectedNodes.removeWhere((node) => node.id == nodeId);
    notifyListeners();
  }

  /// Generate a new 6-digit Node ID for the user and persist to Firebase
  Future<void> generateNewNodeId() async {
    final random = Random();
    final part1 = 100 + random.nextInt(900);
    final part2 = 100 + random.nextInt(900);
    final newId = '$part1 - $part2';

    _currentUser = _currentUser.copyWith(id: newId);
    notifyListeners();

    if (_hasAccount) {
      await FirebaseSyncService.syncNodeLocation(node: _currentUser);
    }
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
      nodeId: _currentUser.id,
      imageBytes: imageBytes,
    );

    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      // Explicitly write URL to user's Realtime Database node
      await FirebaseSyncService.updateProfilePhotoUrl(
        nodeId: _currentUser.id,
        photoUrl: downloadUrl,
      );

      // Update local state so UI reflects the change immediately
      _currentUser = _currentUser.copyWith(
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

    // Clear local session storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Reset user session in memory
    _hasAccount = false;
    _connectedNodes.clear();
    _locationHistory.clear();
    _currentUser = NodeUser(
      id: '000 - 000',
      name: '',
      avatarPath: 'assets/avatars/nuwan.jpg',
      profilePicUrl: null,
      status: 'Offline',
      batteryLevel: 85,
      latitude: 6.9271,
      longitude: 79.8612,
      lastUpdated: DateTime.now(),
      isSelf: true,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _firebasePollTimer?.cancel();
    _adaptiveService.stop();
    super.dispose();
  }
}

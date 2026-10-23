import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/tracking_settings.dart';
import 'background_service.dart';

enum NodeMotionState {
  still,
  walking,
  running,
  inVehicle,
}

extension NodeMotionStateExt on NodeMotionState {
  String get displayName {
    switch (this) {
      case NodeMotionState.still:
        return 'STILL';
      case NodeMotionState.walking:
        return 'WALKING';
      case NodeMotionState.running:
        return 'RUNNING';
      case NodeMotionState.inVehicle:
        return 'IN_VEHICLE';
    }
  }

  bool get isActive => this != NodeMotionState.still;
}

typedef PollingCallback = Future<void> Function({
  required double latitude,
  required double longitude,
  required NodeMotionState motionState,
  required int batteryLevel,
  required int currentIntervalSec,
});

class AdaptivePollingService {
  final Battery _battery = Battery();
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  NodeMotionState _currentMotionState = NodeMotionState.still;
  int _currentBatteryLevel = 85;
  int _secondsUntilNextPoll = 600;
  int _currentIntervalSec = 600;
  bool _isMockSimulationActive = false;

  // Visual Mocking coordinates
  double _currentLat = 6.9271; // Colombo default
  double _currentLng = 79.8612;

  // Smoothing buffers for accelerometer
  final List<double> _accelMagnitudes = [];
  static const int _windowSize = 25;

  PollingCallback? onLocationSync;
  VoidCallback? onStateChanged;

  NodeMotionState get currentMotionState => _currentMotionState;
  int get currentBatteryLevel => _currentBatteryLevel;
  int get secondsUntilNextPoll => _secondsUntilNextPoll;
  int get currentIntervalSec => _currentIntervalSec;
  bool get isMockSimulationActive => _isMockSimulationActive;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;

  /// Start adaptive polling system
  Future<void> start({
    required TrackingSettings settings,
    required PollingCallback onSync,
    required VoidCallback onStateUpdate,
  }) async {
    onLocationSync = onSync;
    onStateChanged = onStateUpdate;

    await _checkBattery();
    _startRealSensorStream();
    _recalculateIntervalAndRestartTimer(settings);
    _startCountdownTimer();

    // Trigger initial poll immediately
    await _performPoll();
  }

  /// Stop polling
  void stop() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    BackgroundService.cancelTrackingNotification();
  }

  /// Check battery level
  Future<void> _checkBattery() async {
    try {
      if (!kIsWeb) {
        final level = await _battery.batteryLevel;
        _currentBatteryLevel = level;
      }
    } catch (e) {
      debugPrint('Battery check error: $e');
    }
  }

  /// Calculate effective polling interval based on PRD state machine:
  /// - LOW BATTERY STATE (<15%): Throttle to 20 mins (1200s)
  /// - STILL STATE: Update every 10 mins (600s or user configured sleepInterval)
  /// - ACTIVE STATE (WALKING, RUNNING, IN_VEHICLE): Scale to 1 min (60s or user configured activeInterval)
  int calculateEffectiveInterval(TrackingSettings settings) {
    if (settings.lowBatterySaver && _currentBatteryLevel < 15) {
      return 1200; // 20 Minutes
    }

    if (_currentMotionState == NodeMotionState.still) {
      return settings.sleepIntervalSec; // 10 Mins (default 600s)
    } else {
      return settings.activeIntervalSec; // 1 Min (default 60s)
    }
  }

  /// Recalculates interval and updates timers
  void _recalculateIntervalAndRestartTimer(TrackingSettings settings) {
    final newInterval = calculateEffectiveInterval(settings);
    _currentIntervalSec = newInterval;
    _secondsUntilNextPoll = newInterval;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(seconds: newInterval), (_) {
      _performPoll();
      _secondsUntilNextPoll = _currentIntervalSec;
    });

    _updateForegroundNotification();
    onStateChanged?.call();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsUntilNextPoll > 0) {
        _secondsUntilNextPoll--;
        onStateChanged?.call();
      }
    });
  }

  /// Update persistent Android foreground notification
  void _updateForegroundNotification() {
    final intervalMin = (_currentIntervalSec / 60).round();
    final intervalText = intervalMin >= 1 ? '$intervalMin min' : '$_currentIntervalSec sec';
    final stateText = _currentBatteryLevel < 15
        ? 'LOW BATTERY SAVER (20 min)'
        : '${_currentMotionState.displayName} ($intervalText)';

    BackgroundService.showPersistentTrackingNotification(
      title: 'NodeLink Active: Securely sharing Location',
      body: 'State: $stateText • Battery: $_currentBatteryLevel%',
    );
  }

  /// Execute GPS capture and trigger sync
  Future<void> _performPoll() async {
    try {
      if (!_isMockSimulationActive && !kIsWeb) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: _currentMotionState == NodeMotionState.still
                  ? LocationAccuracy.medium
                  : LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            ),
          );
          _currentLat = position.latitude;
          _currentLng = position.longitude;
        }
      } else if (_isMockSimulationActive) {
        // Mock movement simulation: incrementally drift coordinates
        final random = Random();
        final step = _currentMotionState == NodeMotionState.inVehicle
            ? 0.0015
            : (_currentMotionState == NodeMotionState.walking ? 0.0004 : 0.00002);
        _currentLat += (random.nextDouble() - 0.5) * step;
        _currentLng += (random.nextDouble() - 0.5) * step;
      }

      await _checkBattery();

      await onLocationSync?.call(
        latitude: _currentLat,
        longitude: _currentLng,
        motionState: _currentMotionState,
        batteryLevel: _currentBatteryLevel,
        currentIntervalSec: _currentIntervalSec,
      );
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  /// Listen to accelerometer when not in manual mock mode
  void _startRealSensorStream() {
    if (kIsWeb) return;
    try {
      _sensorSubscription = userAccelerometerEventStream().listen((event) {
        if (_isMockSimulationActive) return;

        // Calculate 3D acceleration vector magnitude
        final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        _accelMagnitudes.add(magnitude);
        if (_accelMagnitudes.length > _windowSize) {
          _accelMagnitudes.removeAt(0);
        }

        // Classify motion
        final avg = _accelMagnitudes.reduce((a, b) => a + b) / _accelMagnitudes.length;
        final variance = _accelMagnitudes
                .map((m) => pow(m - avg, 2))
                .reduce((a, b) => a + b) /
            _accelMagnitudes.length;

        NodeMotionState detectedState;
        if (variance < 0.25) {
          detectedState = NodeMotionState.still;
        } else if (variance < 1.8) {
          detectedState = NodeMotionState.walking;
        } else if (variance < 5.0) {
          detectedState = NodeMotionState.running;
        } else {
          detectedState = NodeMotionState.inVehicle;
        }

        if (detectedState != _currentMotionState) {
          _currentMotionState = detectedState;
          onStateChanged?.call();
        }
      });
    } catch (e) {
      debugPrint('Sensor stream error: $e');
    }
  }

  /// Visual Mocking Simulator method to simulate driving/walking/still states
  void setMockMotionState(
    NodeMotionState state,
    TrackingSettings settings, {
    int? mockBattery,
  }) {
    _isMockSimulationActive = true;
    _currentMotionState = state;
    if (mockBattery != null) {
      _currentBatteryLevel = mockBattery;
    }
    _recalculateIntervalAndRestartTimer(settings);
    _performPoll();
  }

  /// Disable mock simulation and resume real device sensors
  void disableMockSimulation(TrackingSettings settings) {
    _isMockSimulationActive = false;
    _recalculateIntervalAndRestartTimer(settings);
  }
}

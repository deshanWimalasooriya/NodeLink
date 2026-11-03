import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'chat_sync_service.dart';
import 'e2ee_service.dart';

enum CallState {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  connected,
  ended,
}

class CallService extends ChangeNotifier {
  static final CallService instance = CallService._internal();
  CallService._internal();

  CallState _callState = CallState.idle;
  CallState get callState => _callState;

  String? _peerId;
  String? get peerId => _peerId;

  String _peerName = 'Unknown User';
  String get peerName => _peerName;

  String? _peerAvatar;
  String? get peerAvatar => _peerAvatar;

  String _peerPhone = '';
  String get peerPhone => _peerPhone;

  String _peerDistance = '0.4 km away';
  String get peerDistance => _peerDistance;

  bool _isVideo = false;
  bool get isVideo => _isVideo;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;

  bool _isFrontCamera = true;
  bool get isFrontCamera => _isFrontCamera;

  Duration _callDuration = Duration.zero;
  Duration get callDuration => _callDuration;

  String _connectionQuality = 'Direct Mesh P2P • Strong';
  String get connectionQuality => _connectionQuality;

  String _rsaFingerprint = '';
  String get rsaFingerprint => _rsaFingerprint;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  Timer? _durationTimer;

  Map<String, dynamic>? _incomingOfferData;
  final List<RTCIceCandidate> _queuedCandidates = [];
  bool _isInitialized = false;
  String? _currentCallId;
  String? _activeMyNodeId;

  final StreamController<CallState> _callStateController =
      StreamController<CallState>.broadcast();
  Stream<CallState> get onCallStateChanged => _callStateController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _setupCallKitListener();
      _isInitialized = true;
      debugPrint('[CallService] WebRTC and CallKit initialized successfully.');
    } catch (e) {
      debugPrint('[CallService] Init error: $e');
    }
  }

  void _setupCallKitListener() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      debugPrint('[CallKit] Event: ${event.eventName}');
      switch (event.eventName) {
        case CallEventConstants.actionCallAccept:
          if (_activeMyNodeId != null) {
            acceptCall(myNodeId: _activeMyNodeId!);
          }
          break;
        case CallEventConstants.actionCallDecline:
          if (_activeMyNodeId != null) {
            declineCall(myNodeId: _activeMyNodeId!);
          }
          break;
        case CallEventConstants.actionCallEnded:
          endCall();
          break;
        default:
          break;
      }
    });
  }

  void _setCallState(CallState state) {
    _callState = state;
    _callStateController.add(state);
    notifyListeners();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _callDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Initiates an outgoing voice or video call
  Future<void> startCall({
    required String peerNodeId,
    required String peerName,
    String? peerAvatar,
    String? peerPhone,
    String peerDistance = '0.4 km away',
    required bool isVideo,
    required String myNodeId,
    required String myName,
    String? myAvatar,
  }) async {
    if (!_isInitialized) await initialize();

    _activeMyNodeId = myNodeId;
    _peerId = peerNodeId;
    _peerName = peerName;
    _peerAvatar = peerAvatar;
    _peerPhone = peerPhone ?? peerNodeId;
    _peerDistance = peerDistance;
    _isVideo = isVideo;
    _isVideoEnabled = isVideo;
    _isMuted = false;
    _isSpeakerOn = isVideo; // Default speaker on for video
    _isFrontCamera = true;
    _queuedCandidates.clear();
    _currentCallId = const Uuid().v4();

    _rsaFingerprint = E2EEService.getPublicKeyFingerprint(E2EEService.myPublicKeyPem);
    _setCallState(CallState.outgoingRinging);

    try {
      // 1. Acquire Local Media
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': isVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;

      // 2. Create Peer Connection with Public STUN servers
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // 3. Add Local Tracks to Peer Connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. Handle ICE Candidates
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null && _peerId != null) {
          ChatSyncService.instance.sendSignalingMessage(
            myNodeId: myNodeId,
            peerNodeId: _peerId!,
            type: 'webrtc_ice_candidate',
            data: {
              'callId': _currentCallId,
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          );
        }
      };

      // 5. Handle Remote Tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          remoteRenderer.srcObject = _remoteStream;
          notifyListeners();
        }
      };

      // 6. Handle Connection State
      _peerConnection!.onConnectionState = (state) {
        debugPrint('[CallService] ConnectionState: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _connectionQuality = 'Direct Mesh P2P • Strong';
          _setCallState(CallState.connected);
          _startTimer();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _connectionQuality = 'Reconnecting...';
          notifyListeners();
        }
      };

      // 7. Create Offer and Set Local Description
      final offerConstraints = <String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': isVideo,
      };

      final offer = await _peerConnection!.createOffer(offerConstraints);
      await _peerConnection!.setLocalDescription(offer);

      // 8. Send Offer to Peer via E2EE inbox
      await ChatSyncService.instance.sendSignalingMessage(
        myNodeId: myNodeId,
        peerNodeId: peerNodeId,
        type: 'webrtc_offer',
        data: {
          'callId': _currentCallId,
          'sdp': offer.sdp,
          'type': offer.type,
          'isVideo': isVideo,
          'callerName': myName,
          'callerAvatar': myAvatar,
          'callerPhone': peerPhone ?? myNodeId,
          'peerDistance': peerDistance,
        },
      );
    } catch (e) {
      debugPrint('[CallService] Error starting call: $e');
      endCall();
    }
  }

  /// Processes incoming signaling messages dispatched from ChatSyncService
  Future<void> handleIncomingSignaling({
    required String senderId,
    required String type,
    required Map<String, dynamic> data,
    required String myNodeId,
  }) async {
    _activeMyNodeId = myNodeId;

    switch (type) {
      case 'webrtc_offer':
        await _handleIncomingOffer(senderId: senderId, data: data);
        break;

      case 'webrtc_answer':
        await _handleIncomingAnswer(data: data);
        break;

      case 'webrtc_ice_candidate':
        await _handleIncomingIceCandidate(data: data);
        break;

      case 'webrtc_hangup':
        endCall(sendHangup: false);
        break;
    }
  }

  Future<void> _handleIncomingOffer({
    required String senderId,
    required Map<String, dynamic> data,
  }) async {
    if (_callState != CallState.idle) {
      // Busy: decline incoming offer
      ChatSyncService.instance.sendSignalingMessage(
        myNodeId: _activeMyNodeId ?? '',
        peerNodeId: senderId,
        type: 'webrtc_hangup',
        data: {'reason': 'busy'},
      );
      return;
    }

    if (!_isInitialized) await initialize();

    _incomingOfferData = data;
    _peerId = senderId;
    _currentCallId = data['callId']?.toString() ?? const Uuid().v4();
    _peerName = data['callerName']?.toString() ?? 'NodeLink Peer';
    _peerAvatar = data['callerAvatar']?.toString();
    _peerPhone = data['callerPhone']?.toString() ?? senderId;
    _peerDistance = data['peerDistance']?.toString() ?? '0.4 km away';
    _isVideo = data['isVideo'] == true;
    _isVideoEnabled = _isVideo;
    _isMuted = false;
    _isSpeakerOn = _isVideo;
    _isFrontCamera = true;
    _queuedCandidates.clear();

    _rsaFingerprint = E2EEService.getPublicKeyFingerprint(E2EEService.myPublicKeyPem);
    _setCallState(CallState.incomingRinging);

    // Trigger Native OS-level CallKit incoming call screen/popup
    try {
      final callKitParams = CallKitParams(
        id: _currentCallId!,
        nameCaller: _peerName,
        appName: 'NodeLink',
        avatar: _peerAvatar,
        handle: _peerPhone,
        type: _isVideo ? 1 : 0,
        duration: 35000,
        extra: <String, dynamic>{
          'peerId': senderId,
          'isVideo': _isVideo,
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0B141A',
          actionColor: '#00A884',
          textColor: '#FFFFFF',
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    } catch (e) {
      debugPrint('[CallKit] Error showing incoming call popup: $e');
    }
  }

  Future<void> _handleIncomingAnswer({required Map<String, dynamic> data}) async {
    try {
      final sdp = data['sdp']?.toString();
      final type = data['type']?.toString() ?? 'answer';
      if (sdp == null) return;

      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, type),
        );

        // Process queued ICE candidates
        for (final candidate in _queuedCandidates) {
          await _peerConnection!.addCandidate(candidate);
        }
        _queuedCandidates.clear();

        _setCallState(CallState.connected);
        _startTimer();
      }
    } catch (e) {
      debugPrint('[CallService] Error setting remote answer: $e');
    }
  }

  Future<void> _handleIncomingIceCandidate({required Map<String, dynamic> data}) async {
    try {
      final candidateStr = data['candidate']?.toString();
      final sdpMid = data['sdpMid']?.toString();
      final sdpMLineIndex = data['sdpMLineIndex'] is int
          ? data['sdpMLineIndex'] as int
          : int.tryParse(data['sdpMLineIndex']?.toString() ?? '0') ?? 0;

      if (candidateStr == null) return;

      final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);

      if (_peerConnection != null && _peerConnection!.signalingState != RTCSignalingState.RTCSignalingStateClosed) {
        final remoteDesc = await _peerConnection!.getRemoteDescription();
        if (remoteDesc != null) {
          await _peerConnection!.addCandidate(candidate);
          return;
        }
      }
      _queuedCandidates.add(candidate);
    } catch (e) {
      debugPrint('[CallService] Error handling candidate: $e');
    }
  }

  /// User Accepts incoming call
  Future<void> acceptCall({required String myNodeId}) async {
    if (_incomingOfferData == null || _peerId == null) return;

    _activeMyNodeId = myNodeId;
    await FlutterCallkitIncoming.endAllCalls();
    _setCallState(CallState.connecting);

    try {
      // 1. Acquire Local Media
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': _isVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;

      // 2. Create Peer Connection
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // 3. Add Local Tracks
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. ICE candidate handler
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null && _peerId != null) {
          ChatSyncService.instance.sendSignalingMessage(
            myNodeId: myNodeId,
            peerNodeId: _peerId!,
            type: 'webrtc_ice_candidate',
            data: {
              'callId': _currentCallId,
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          );
        }
      };

      // 5. Remote Track handler
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          remoteRenderer.srcObject = _remoteStream;
          notifyListeners();
        }
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('[CallService] Accepted Call State: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _connectionQuality = 'Direct Mesh P2P • Strong';
          _setCallState(CallState.connected);
          _startTimer();
        }
      };

      // 6. Set Remote Offer Description
      final offerSdp = _incomingOfferData!['sdp']?.toString() ?? '';
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerSdp, 'offer'),
      );

      // 7. Drain queued ICE Candidates
      for (final candidate in _queuedCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _queuedCandidates.clear();

      // 8. Create Answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // 9. Send Answer via E2EE inbox
      await ChatSyncService.instance.sendSignalingMessage(
        myNodeId: myNodeId,
        peerNodeId: _peerId!,
        type: 'webrtc_answer',
        data: {
          'callId': _currentCallId,
          'sdp': answer.sdp,
          'type': answer.type,
        },
      );

      _setCallState(CallState.connected);
      _startTimer();
    } catch (e) {
      debugPrint('[CallService] Error accepting call: $e');
      endCall();
    }
  }

  /// User Declines incoming call
  Future<void> declineCall({required String myNodeId}) async {
    if (_peerId != null) {
      await ChatSyncService.instance.sendSignalingMessage(
        myNodeId: myNodeId,
        peerNodeId: _peerId!,
        type: 'webrtc_hangup',
        data: {'callId': _currentCallId, 'reason': 'declined'},
      );
    }
    await FlutterCallkitIncoming.endAllCalls();
    await _cleanupCall();
    _setCallState(CallState.idle);
  }

  /// Ends an active or pending call
  Future<void> endCall({bool sendHangup = true}) async {
    if (_peerId != null && sendHangup && _activeMyNodeId != null) {
      try {
        await ChatSyncService.instance.sendSignalingMessage(
          myNodeId: _activeMyNodeId!,
          peerNodeId: _peerId!,
          type: 'webrtc_hangup',
          data: {'callId': _currentCallId, 'reason': 'ended'},
        );
      } catch (e) {
        debugPrint('[CallService] Error sending hangup: $e');
      }
    }

    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}

    await _cleanupCall();
    _setCallState(CallState.ended);

    // Return to idle after a brief transition
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_callState == CallState.ended) {
        _setCallState(CallState.idle);
      }
    });
  }

  Future<void> _cleanupCall() async {
    _stopTimer();

    // 1. Detach renderers immediately so Camera2 stops receiving streaming surface requests
    try {
      localRenderer.srcObject = null;
    } catch (_) {}
    try {
      remoteRenderer.srcObject = null;
    } catch (_) {}

    // 2. Safely stop and disable all video and audio tracks
    try {
      if (_localStream != null) {
        for (final track in _localStream!.getVideoTracks()) {
          try {
            track.enabled = false;
            await track.stop();
          } catch (e) {
            debugPrint('[CallService] Error stopping video track: $e');
          }
        }
        for (final track in _localStream!.getAudioTracks()) {
          try {
            track.enabled = false;
            await track.stop();
          } catch (e) {
            debugPrint('[CallService] Error stopping audio track: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[CallService] Error clearing media tracks: $e');
    }

    // 3. Dispose streams and peer connection safely in finally
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      await _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (_) {}
    _peerConnection = null;

    _queuedCandidates.clear();
    _incomingOfferData = null;
    _currentCallId = null;
    _callDuration = Duration.zero;
  }

  // --------------------------------------------------------------------------
  // In-Call Device & Media Controls
  // --------------------------------------------------------------------------

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  void toggleCamera() {
    _isVideoEnabled = !_isVideoEnabled;
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = _isVideoEnabled;
      }
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
      _isFrontCamera = !_isFrontCamera;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callStateController.close();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}

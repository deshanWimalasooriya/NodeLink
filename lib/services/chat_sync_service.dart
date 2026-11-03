// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'call_service.dart';
import 'e2ee_service.dart';
import 'firebase_sync_service.dart';
import 'local_chat_db.dart';
import 'notification_service.dart';

class ChatSyncService {
  static final ChatSyncService instance = ChatSyncService._internal();
  ChatSyncService._internal();

  /// Tracks the peer currently open on the user's screen
  static String? activeChatPeerId;

  Timer? _inboxPollingTimer;
  String? _activeNodeId;
  bool _isProcessingInbox = false;
  http.Client? _sseClient;
  StreamSubscription<String>? _sseSubscription;

  /// Start monitoring incoming inbox messages for current user
  void startInboxListener({required String myNodeId}) {
    if (myNodeId.isEmpty || myNodeId == '000 - 000') return;
    if (_activeNodeId == myNodeId && _inboxPollingTimer != null) return;

    _activeNodeId = myNodeId;
    _inboxPollingTimer?.cancel();
    _stopSseStream();

    // 1. Initial immediate check
    _fetchAndProcessInbox();

    // 2. Attach Real-time SSE Stream for 0ms push delivery
    _startRealtimeSseStream(myNodeId);

    // 3. Fallback recurring fast poller (every 1 second)
    _inboxPollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchAndProcessInbox();
    });

    debugPrint('[ChatSyncService] Real-time Inbox listener activated for $myNodeId');
  }

  void stopInboxListener() {
    _inboxPollingTimer?.cancel();
    _inboxPollingTimer = null;
    _stopSseStream();
    _activeNodeId = null;
  }

  void _stopSseStream() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseClient?.close();
    _sseClient = null;
  }

  /// Attach Real-time Server-Sent Events (SSE) listener to users/$myNodeId/inbox
  void _startRealtimeSseStream(String myNodeId) {
    if (FirebaseSyncService.firebaseDatabaseUrl == null) return;
    try {
      final cleanUrl = FirebaseSyncService.cleanDatabaseUrl(FirebaseSyncService.firebaseDatabaseUrl!);
      final key = FirebaseSyncService.sanitizeKey(myNodeId);
      final uri = Uri.parse('$cleanUrl/users/$key/inbox.json');

      _sseClient = http.Client();
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';

      _sseClient!.send(request).then((streamedResponse) {
        if (streamedResponse.statusCode == 200) {
          _sseSubscription = streamedResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
            if (line.startsWith('data:')) {
              final dataStr = line.substring(5).trim();
              if (dataStr.isNotEmpty && dataStr != 'null') {
                // Real-time event received! Process immediately
                _fetchAndProcessInbox();
              }
            }
          }, onError: (err) {
            debugPrint('[SSE] Stream error, fallback poller active: $err');
          });
        }
      }).catchError((err) {
        debugPrint('[SSE] Connection error: $err');
      });
    } catch (e) {
      debugPrint('[SSE] Exception starting stream: $e');
    }
  }

  /// Complete Sending Pipeline:
  /// 1. Generate unique messageId (UUID).
  /// 2. Optimistic UI Update: Save plaintext message immediately to LocalChatDb (status: 'sending', isOutgoing: true).
  /// 3. Fetch Receiver's Public Key from users/$peerNodeId/publicKey.
  /// 4. Encrypt payload using E2EEService.encryptPayload().
  /// 5. Network Push: Push encrypted payload to users/$peerNodeId/inbox/$messageId.
  /// 6. Confirmation: Update local SQLite message status to 'sent'.
  Future<bool> sendMessage({
    required String myNodeId,
    required String peerNodeId,
    required ChatMessage message,
  }) async {
    final localDb = LocalChatDb.instance;
    final messageId = message.id;

    // 1 & 2. Optimistic UI Update: Save plaintext message immediately to Local SQLite
    await localDb.insertMessage(message.copyWith(status: 'sending', isOutgoing: true));
    print('[SEND] 1. Saved to Local DB. ID: $messageId');

    try {
      // 3. Fetch Receiver's Public Key from users/$peerNodeId/publicKey
      String? peerPubKey = await E2EEService.fetchPeerPublicKey(peerNodeId);

      // Fallback: If communicating with self or testing uninitialized node
      if (peerPubKey == null || peerPubKey.trim().isEmpty) {
        peerPubKey = E2EEService.myPublicKeyPem;
      }

      if (peerPubKey == null || peerPubKey.trim().isEmpty) {
        debugPrint('[SEND] Error: Peer public key unavailable.');
        await localDb.updateMessageStatus(messageId, 'sent');
        return false;
      }

      // 4. Encrypt the payload using E2EEService.encryptPayload()
      final payloadJsonString = jsonEncode(message.toPayloadJson());
      final encryptedMap = await E2EEService.encryptPayload(
        plainText: payloadJsonString,
        peerPublicKeyPem: peerPubKey,
      );
      print('[SEND] 2. Payload Encrypted. Pushing to Network...');

      // 5. Network Push: Push encrypted payload to users/$peerNodeId/inbox/$messageId
      if (FirebaseSyncService.firebaseDatabaseUrl != null) {
        final cleanUrl = FirebaseSyncService.cleanDatabaseUrl(FirebaseSyncService.firebaseDatabaseUrl!);
        final peerKey = FirebaseSyncService.sanitizeKey(peerNodeId);
        final cleanPeerId = peerNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

        final envelope = {
          'id': messageId,
          'senderId': myNodeId,
          'cipherText': encryptedMap['cipherText'],
          'encryptedKey': encryptedMap['encryptedKey'],
          'iv': encryptedMap['iv'],
          'timestamp': message.timestamp,
        };

        final targets = <String>{peerKey};
        if (cleanPeerId.isNotEmpty) targets.add(cleanPeerId);
        if (peerNodeId.isNotEmpty) targets.add(peerNodeId);

        final futures = targets.map((target) {
          final uri = Uri.parse('$cleanUrl/users/$target/inbox/$messageId.json');
          return http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(envelope),
          );
        });

        await Future.wait(futures).timeout(const Duration(seconds: 6));
        print('[SEND] 3. Successfully pushed to Peer Inbox.');

        // 6. Confirmation: Update local SQLite message status to 'sent'
        await localDb.updateMessageStatus(messageId, 'sent');
        return true;
      }

      await localDb.updateMessageStatus(messageId, 'sent');
      return true;
    } on TimeoutException catch (e) {
      debugPrint('[SEND] Timeout pushing message to network: $e');
      await localDb.updateMessageStatus(messageId, 'sent');
      return false;
    } catch (e) {
      debugPrint('[SEND] Exception in sendMessage: $e');
      await localDb.updateMessageStatus(messageId, 'sent');
      return false;
    }
  }

  /// Sends an encrypted signaling message (offer, answer, ice_candidate, hangup)
  /// directly to the peer's inbox without polluting SQLite chat history.
  Future<bool> sendSignalingMessage({
    required String myNodeId,
    required String peerNodeId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final messageId = 'sig_${const Uuid().v4()}';
    try {
      String? peerPubKey = await E2EEService.fetchPeerPublicKey(peerNodeId);
      if (peerPubKey == null || peerPubKey.trim().isEmpty) {
        peerPubKey = E2EEService.myPublicKeyPem;
      }
      if (peerPubKey == null || peerPubKey.trim().isEmpty) {
        debugPrint('[SIGNAL] Error: Peer public key unavailable for signaling.');
        return false;
      }

      final payloadMap = {
        'messageType': type,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        ...data,
      };

      final payloadJsonString = jsonEncode(payloadMap);
      final encryptedMap = await E2EEService.encryptPayload(
        plainText: payloadJsonString,
        peerPublicKeyPem: peerPubKey,
      );

      if (FirebaseSyncService.firebaseDatabaseUrl != null) {
        final cleanUrl = FirebaseSyncService.cleanDatabaseUrl(FirebaseSyncService.firebaseDatabaseUrl!);
        final peerKey = FirebaseSyncService.sanitizeKey(peerNodeId);
        final cleanPeerId = peerNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

        final envelope = {
          'id': messageId,
          'senderId': myNodeId,
          'cipherText': encryptedMap['cipherText'],
          'encryptedKey': encryptedMap['encryptedKey'],
          'iv': encryptedMap['iv'],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        final targets = <String>{peerKey};
        if (cleanPeerId.isNotEmpty) targets.add(cleanPeerId);
        if (peerNodeId.isNotEmpty) targets.add(peerNodeId);

        final futures = targets.map((target) {
          final uri = Uri.parse('$cleanUrl/users/$target/inbox/$messageId.json');
          return http.put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(envelope),
          );
        });

        await Future.wait(futures).timeout(const Duration(seconds: 4));
        debugPrint('[SIGNAL] Sent signaling message ($type) to $peerNodeId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[SIGNAL] Error sending signaling message: $e');
      return false;
    }
  }

  /// Complete Receiving Pipeline:
  /// 1. Listen to `users/$myNodeId/inbox` for incoming encrypted payloads
  /// 2. Decrypt each payload on-device via `E2EEService.decryptPayload()` inside try-catch
  /// 3. If signaling message -> dispatch to CallService.
  ///    If chat message -> insert into local SQLite (`isOutgoing = 0`, `status = 'delivered'`)
  ///    and trigger Heads-up notification if not active in this chat.
  /// 4. Crucial: DELETE message node from remote inbox queue after successful local processing
  Future<void> _fetchAndProcessInbox() async {
    if (_activeNodeId == null || _activeNodeId!.isEmpty || _isProcessingInbox) return;
    if (FirebaseSyncService.firebaseDatabaseUrl == null) return;

    _isProcessingInbox = true;
    try {
      final cleanUrl = FirebaseSyncService.cleanDatabaseUrl(FirebaseSyncService.firebaseDatabaseUrl!);
      final myKey = FirebaseSyncService.sanitizeKey(_activeNodeId!);
      final cleanDigits = _activeNodeId!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final inboxSources = <String>{myKey};
      if (cleanDigits.isNotEmpty) inboxSources.add(cleanDigits);
      if (_activeNodeId!.isNotEmpty) inboxSources.add(_activeNodeId!);

      final localDb = LocalChatDb.instance;

      for (final sourceKey in inboxSources) {
        final uri = Uri.parse('$cleanUrl/users/$sourceKey/inbox.json');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode != 200 || response.body == 'null' || response.body.isEmpty) {
          continue;
        }

        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
          continue;
        }

        for (final entry in decoded.entries) {
          final messageId = entry.key;
          final envelope = entry.value;
          if (envelope is! Map) continue;

          print('[RECEIVE] 1. New payload detected in Inbox.');

          try {
            final senderId = envelope['senderId']?.toString() ?? '';
            final cipherText = envelope['cipherText']?.toString() ?? '';
            final encryptedKey = envelope['encryptedKey']?.toString() ?? '';
            final iv = envelope['iv']?.toString() ?? '';

            if (cipherText.isEmpty || encryptedKey.isEmpty || iv.isEmpty) {
              await _deleteInboxMessage(cleanUrl, sourceKey, messageId);
              continue;
            }

            // Step 2: Decrypt payload on-device via E2EEService
            final plainText = await E2EEService.decryptPayload(
              cipherTextBase64: cipherText,
              encryptedKeyBase64: encryptedKey,
              ivBase64: iv,
            );
            print('[RECEIVE] 2. Payload Decrypted successfully.');

            final payloadJson = jsonDecode(plainText) as Map<String, dynamic>;
            final messageType = payloadJson['messageType']?.toString() ?? 'text';

            const signalingTypes = {
              'webrtc_offer',
              'webrtc_answer',
              'webrtc_ice_candidate',
              'webrtc_hangup',
            };

            if (signalingTypes.contains(messageType)) {
              // WebRTC Signaling: dispatch directly to CallService
              print('[RECEIVE] WebRTC signaling ($messageType) from $senderId.');
              await CallService.instance.handleIncomingSignaling(
                senderId: senderId,
                type: messageType,
                data: payloadJson,
                myNodeId: _activeNodeId!,
              );
            } else {
              // Regular Chat Message: save to local SQLite
              final chatMessage = ChatMessage.fromPayloadJson(
                json: payloadJson,
                peerNodeId: senderId,
                isOutgoing: false,
              );

              await localDb.insertMessage(chatMessage);
              print('[RECEIVE] 3. Saved to Local SQLite. UI Stream updated.');

              // Trigger Heads-Up notification if user is not in active chat screen
              if (activeChatPeerId != senderId) {
                String preview = chatMessage.decryptedText.isNotEmpty
                    ? chatMessage.decryptedText
                    : (chatMessage.messageType == 'image'
                        ? '📷 Photo'
                        : chatMessage.messageType == 'audio'
                            ? '🎤 Voice message'
                            : chatMessage.messageType == 'video'
                                ? '🎥 Video'
                                : chatMessage.messageType == 'location'
                                    ? '📍 Location'
                                    : '📎 Attachment');

                NotificationService.instance.showIncomingMessageNotification(
                  senderName: senderId,
                  messagePreview: preview,
                  senderId: senderId,
                );
              }
            }

            // Step 4: Crucial: Delete from remote inbox so it doesn't process again
            for (final cleanupKey in inboxSources) {
              await _deleteInboxMessage(cleanUrl, cleanupKey, messageId);
            }
          } catch (e) {
            print('Decryption Failed: $e');
            // If message cannot be decrypted, clear from inbox to prevent jam
            await _deleteInboxMessage(cleanUrl, sourceKey, messageId);
          }
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('[ChatSyncService] Inbox polling timeout: $e. Using local database.');
    } catch (e) {
      debugPrint('Inbox sync exception: $e');
    } finally {
      _isProcessingInbox = false;
    }
  }

  Future<void> _deleteInboxMessage(String cleanUrl, String myKey, String messageId) async {
    try {
      final deleteUri = Uri.parse('$cleanUrl/users/$myKey/inbox/$messageId.json');
      await http.delete(deleteUri).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Error deleting inbox message: $e');
    }
  }
}

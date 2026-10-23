import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/node_user.dart';

class FirebaseSyncService {
  // Configurable Firebase Realtime Database URL (Spark Free Tier)
  static String? firebaseDatabaseUrl =
      'https://nodelink-5232f-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Converts any string ID (like '842 - 915') into a valid Firebase Realtime Database path key
  static String sanitizeKey(String id) {
    final clean = id
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.startsWith('node_') ? clean : 'node_$clean';
  }

  /// Helper to convert Firebase Console browser URLs into valid RTDB REST endpoints
  static String cleanDatabaseUrl(String rawUrl) {
    var clean = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final consoleMatch = RegExp(r'database/([^/]+)/').firstMatch(clean);
    if (consoleMatch != null) {
      final dbName = consoleMatch.group(1);
      return 'https://$dbName.asia-southeast1.firebasedatabase.app';
    }
    return clean;
  }

  /// Sync node's complete details to Firebase Realtime Database
  /// Path: `users/<sanitized_node_id>/`
  /// Stores: id, name, email, phone, avatar, status, is_moving, battery, location (lat, lng, timestamp)
  static Future<bool> syncNodeLocation({
    required NodeUser node,
  }) async {
    final payload = node.toFirebaseJson();

    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final key = sanitizeKey(node.id);
        final uri = Uri.parse('$cleanUrl/users/$key.json');

        final response = await http
            .put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          debugPrint('Firebase RTDB Synced successfully for node: ${node.id} ($key)');
          return true;
        } else {
          debugPrint('Firebase RTDB error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('Firebase RTDB sync network exception: $e');
      }
    } else {
      debugPrint('[Firebase Local Resilient Mode] -> users/${node.id}: ${jsonEncode(payload)}');
    }

    return true;
  }

  /// Fetch all active nodes directly from Firebase Realtime Database
  /// Returns a map of key -> NodeUser
  static Future<Map<String, NodeUser>> fetchAllNodes() async {
    final Map<String, NodeUser> results = {};

    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final uri = Uri.parse('$cleanUrl/users.json');

        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.body != 'null') {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            data.forEach((key, val) {
              if (val is Map<String, dynamic>) {
                final id = (val['id'] as String?) ?? key;
                results[id] = NodeUser.fromFirebaseJson(id, val);
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching all nodes from Firebase: $e');
      }
    }
    return results;
  }

  /// Seed initial nodes into Firebase Realtime Database if empty or missing
  static Future<void> seedInitialNodes(List<NodeUser> nodes) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return;

    for (final node in nodes) {
      await syncNodeLocation(node: node);
    }
  }

  /// Fetch a single peer node by its raw ID or sanitized key
  static Future<NodeUser?> fetchNode(String nodeId) async {
    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final key = sanitizeKey(nodeId);
        final uri = Uri.parse('$cleanUrl/users/$key.json');

        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.body != 'null') {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final id = (data['id'] as String?) ?? nodeId;
          return NodeUser.fromFirebaseJson(id, data);
        }
      } catch (e) {
        debugPrint('Error fetching node $nodeId from Firebase: $e');
      }
    }
    return null;
  }

  /// Delete a node from Firebase Realtime Database
  static Future<bool> deleteNode(String nodeId) async {
    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final key = sanitizeKey(nodeId);
        final uri = Uri.parse('$cleanUrl/users/$key.json');

        final response = await http.delete(uri).timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } catch (e) {
        debugPrint('Error deleting node $nodeId from Firebase: $e');
      }
    }
    return false;
  }

  /// Link two node IDs as active connections in Firebase Realtime Database
  static Future<bool> linkNodes(String userId, String neighborId) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final userKey = sanitizeKey(userId);
      final neighborKey = sanitizeKey(neighborId);

      // 1. Link in user's active_connections: users/<user_id>/active_connections/<neighbor_id>: true
      await http.put(
        Uri.parse('$cleanUrl/users/$userKey/active_connections/$neighborKey.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      );

      // 2. Mutual link in neighbor's active_connections
      await http.put(
        Uri.parse('$cleanUrl/users/$neighborKey/active_connections/$userKey.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      );

      debugPrint('Successfully linked nodes in Firebase: $userKey <-> $neighborKey');
      return true;
    } catch (e) {
      debugPrint('Error linking nodes in Firebase: $e');
      return false;
    }
  }

  /// Fetch list of active connection node IDs for a user
  static Future<List<String>> fetchActiveConnections(String userId) async {
    final List<String> connections = [];
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return connections;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final userKey = sanitizeKey(userId);
      final response = await http.get(Uri.parse('$cleanUrl/users/$userKey/active_connections.json'));
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          connections.addAll(data.keys);
        }
      }
    } catch (e) {
      debugPrint('Error fetching active connections: $e');
    }
    return connections;
  }

  /// Stream that listens to a neighbor node's location in Firebase
  /// Listens to `users/<neighbor_id>/location`
  static Stream<Map<String, dynamic>?> streamNeighborLocation(String neighborId) async* {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return;
    final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
    final key = sanitizeKey(neighborId);

    while (true) {
      try {
        final res = await http.get(Uri.parse('$cleanUrl/users/$key/location.json'));
        if (res.statusCode == 200 && res.body != 'null') {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            yield data;
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Upload compressed profile picture to Firebase Cloud Storage
  /// Target path: `profile_photos/<node_id>.jpg`
  /// Retrieves the public download URL and saves it to the user's data node in the Firebase RTDB.
  static Future<String?> uploadProfilePhoto({
    required String nodeId,
    required Uint8List imageBytes,
  }) async {
    final cleanNodeId = sanitizeKey(nodeId);
    final storagePath = 'profile_photos/$cleanNodeId.jpg';
    final bucket = 'nodelink-5232f.firebasestorage.app';

    String? publicUrl;

    try {
      // 1. Upload to Firebase Cloud Storage via standard REST upload
      final uploadUri = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o?uploadType=media&name=${Uri.encodeComponent(storagePath)}',
      );

      final response = await http.post(
        uploadUri,
        headers: {
          'Content-Type': 'image/jpeg',
        },
        body: imageBytes,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['downloadTokens']?.toString().split(',').first;
        if (token != null && token.isNotEmpty) {
          publicUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}?alt=media&token=$token';
        } else {
          publicUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}?alt=media';
        }
        debugPrint('Firebase Storage uploaded successfully: $publicUrl');
      } else {
        debugPrint('Firebase Storage HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Firebase Storage upload error: $e');
    }

    // Resilient Fallback: If cloud storage bucket rejected or offline, store compact base64
    // so profile picture still renders smoothly and saves to Firebase RTDB
    if (publicUrl == null || publicUrl.isEmpty) {
      publicUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    }

    // 2. Save download URL to the user's data node in Firebase Realtime Database
    await updateProfilePhotoUrl(nodeId: nodeId, photoUrl: publicUrl);

    return publicUrl;
  }

  /// Update profile photo URL directly in Firebase Realtime Database: `users/<node_id>/profile_pic_url`
  static Future<bool> updateProfilePhotoUrl({
    required String nodeId,
    required String photoUrl,
  }) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final key = sanitizeKey(nodeId);
      final uri = Uri.parse('$cleanUrl/users/$key/profile_pic_url.json');

      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(photoUrl),
      ).timeout(const Duration(seconds: 6));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating profile photo URL in Firebase RTDB: $e');
      return false;
    }
  }
}


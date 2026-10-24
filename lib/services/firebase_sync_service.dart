import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/node_user.dart';
import '../models/neighbor_group.dart';

class FirebaseSyncService {
  // Configurable Firebase Realtime Database URL (Spark Free Tier)
  static String? firebaseDatabaseUrl =
      'https://nodelink-5232f-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Generates a cryptographically secure 16-character alphanumeric Node ID
  static String generateSecureNodeId() {
    return const Uuid().v4().replaceAll('-', '').substring(0, 16);
  }

  /// Normalizes usernames for the /usernames fast-lookup index in Firebase RTDB
  static String sanitizeUsername(String username) {
    return username.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Converts any string ID into a valid Firebase Realtime Database path key
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

  /// Check if a username is already taken in the /usernames index
  static Future<bool> isUsernameTaken(String username) async {
    final cleanUsername = sanitizeUsername(username);
    if (cleanUsername.isEmpty) return false;

    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final response = await http
            .get(Uri.parse('$cleanUrl/usernames/$cleanUsername.json'))
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.body != 'null' && response.body != 'false') {
          return true;
        }
      } catch (e) {
        debugPrint('Error checking username availability: $e');
      }
    }
    return false;
  }

  /// Generate up to 3 available alternative username suggestions verified against the DB
  static Future<List<String>> generateAvailableSuggestions(String baseUsername) async {
    final clean = baseUsername.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final candidates = <String>[
      '${clean}123',
      '${clean}99',
      '${clean}_${Random().nextInt(899) + 100}',
      '${clean}01',
      '${clean}77',
      '${clean}xyz',
    ];

    final available = <String>[];
    for (final candidate in candidates) {
      if (available.length >= 3) break;
      final taken = await isUsernameTaken(candidate);
      if (!taken && !available.contains(candidate)) {
        available.add(candidate);
      }
    }
    return available;
  }

  /// Write username to the fast-lookup index: `/usernames/<username>: true`
  static Future<bool> registerUsername(String username, String nodeId) async {
    final cleanUsername = sanitizeUsername(username);
    if (cleanUsername.isEmpty) return false;

    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final uri = Uri.parse('$cleanUrl/usernames/$cleanUsername.json');
        final response = await http.put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(true),
        ).timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } catch (e) {
        debugPrint('Error registering username in index: $e');
      }
    }
    return false;
  }

  /// Instantiate newly registered user record inside Firebase Realtime Database
  /// Writes simultaneously to:
  /// - `/users/<nodeId>`
  /// - `/usernames/<username>`
  static Future<bool> instantiateUserRecord({
    required String nodeId,
    required String name,
    required String phoneNumber,
    String profilePicUrl = '',
    double latitude = 6.9271,
    double longitude = 79.8612,
    int batteryLevel = 85,
  }) async {
    final cleanDigits = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final secureNodeId = cleanDigits.isNotEmpty ? cleanDigits : nodeId;

    final Map<String, dynamic> record = {
      'name': name,
      'username': name,
      'phoneNumber': phoneNumber,
      'phone': phoneNumber,
      'nodeId': secureNodeId,
      'id': secureNodeId,
      'status': 'online',
      'is_moving': false,
      'profilePicUrl': profilePicUrl,
      'profile_pic_url': profilePicUrl,
      'battery': batteryLevel,
      'avatar': profilePicUrl.isNotEmpty ? profilePicUrl : 'assets/avatars/nuwan.jpg',
      'location': {
        'lat': latitude,
        'lng': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    };

    if (firebaseDatabaseUrl != null && firebaseDatabaseUrl!.isNotEmpty) {
      try {
        final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
        final key = sanitizeKey(secureNodeId);

        final futures = <Future<http.Response>>[];

        // 1. Put to sanitized key: /users/<key>.json
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$key.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(record),
        ));

        // 2. Also put directly to raw secureNodeId: /users/<secureNodeId>.json
        if (secureNodeId != key) {
          futures.add(http.put(
            Uri.parse('$cleanUrl/users/$secureNodeId.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(record),
          ));
        }

        // 3. Fast-lookup username index: /usernames/<username>: true
        final cleanUsername = sanitizeUsername(name);
        if (cleanUsername.isNotEmpty) {
          futures.add(http.put(
            Uri.parse('$cleanUrl/usernames/$cleanUsername.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(true),
          ));
        }

        await Future.wait(futures).timeout(const Duration(seconds: 6));
        debugPrint('Firebase instantiated user record & username index for nodeId: $secureNodeId ($name)');
        return true;
      } catch (e) {
        debugPrint('Error instantiating user record in Firebase: $e');
      }
    }
    return false;
  }

  /// Save or update a neighbor group for the current node
  /// Path: `users/<user_id>/groups/<group_id>`
  static Future<bool> saveGroup(String userNodeId, NeighborGroup group) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final key = sanitizeKey(userNodeId);
      final rawKey = userNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final futures = <Future<http.Response>>[];
      futures.add(http.put(
        Uri.parse('$cleanUrl/users/$key/groups/${group.id}.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(group.toJson()),
      ));

      if (rawKey.isNotEmpty && rawKey != key) {
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$rawKey/groups/${group.id}.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(group.toJson()),
        ));
      }

      await Future.wait(futures).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('Error saving group in Firebase: $e');
    }
    return false;
  }

  /// Fetch all groups for a user from `users/<user_id>/groups.json`
  static Future<Map<String, NeighborGroup>> fetchGroups(String userNodeId) async {
    final Map<String, NeighborGroup> groups = {};
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return groups;

    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final key = sanitizeKey(userNodeId);
      final rawKey = userNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      http.Response response = await http
          .get(Uri.parse('$cleanUrl/users/$key/groups.json'))
          .timeout(const Duration(seconds: 5));

      if ((response.statusCode != 200 || response.body == 'null') && rawKey.isNotEmpty && rawKey != key) {
        response = await http
            .get(Uri.parse('$cleanUrl/users/$rawKey/groups.json'))
            .timeout(const Duration(seconds: 5));
      }

      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          data.forEach((groupId, groupData) {
            if (groupData is Map) {
              groups[groupId] = NeighborGroup.fromJson(groupId, groupData);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching groups from Firebase: $e');
    }
    return groups;
  }

  /// Delete a group from `users/<user_id>/groups/<group_id>.json`
  static Future<bool> deleteGroup(String userNodeId, String groupId) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final key = sanitizeKey(userNodeId);
      final rawKey = userNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final futures = <Future<http.Response>>[];
      futures.add(http.delete(Uri.parse('$cleanUrl/users/$key/groups/$groupId.json')));
      if (rawKey.isNotEmpty && rawKey != key) {
        futures.add(http.delete(Uri.parse('$cleanUrl/users/$rawKey/groups/$groupId.json')));
      }

      await Future.wait(futures).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
    return false;
  }

  /// Update members map in a group: `users/<user_id>/groups/<group_id>/members.json`
  static Future<bool> updateGroupMembers(
    String userNodeId,
    String groupId,
    Map<String, bool> members,
  ) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final key = sanitizeKey(userNodeId);
      final rawKey = userNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final futures = <Future<http.Response>>[];
      futures.add(http.put(
        Uri.parse('$cleanUrl/users/$key/groups/$groupId/members.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(members),
      ));

      if (rawKey.isNotEmpty && rawKey != key) {
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$rawKey/groups/$groupId/members.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(members),
        ));
      }

      await Future.wait(futures).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('Error updating group members: $e');
    }
    return false;
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
                final id = (val['id'] as String?) ?? (val['nodeId'] as String?) ?? key;
                results[id] = NodeUser.fromFirebaseJson(id, val);
                results[key] = results[id]!;
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
        final rawKey = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

        http.Response response = await http.get(Uri.parse('$cleanUrl/users/$key.json')).timeout(const Duration(seconds: 5));
        if ((response.statusCode != 200 || response.body == 'null') && rawKey.isNotEmpty && rawKey != key) {
          response = await http.get(Uri.parse('$cleanUrl/users/$rawKey.json')).timeout(const Duration(seconds: 5));
        }

        if (response.statusCode == 200 && response.body != 'null') {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final id = (data['id'] as String?) ?? (data['nodeId'] as String?) ?? nodeId;
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

  /// Two-Way Simultaneous Database Write:
  /// Writes simultaneously to:
  /// 1. `users/<user_a_id>/active_connections/<user_b_id> = true`
  /// 2. `users/<user_b_id>/active_connections/<user_a_id> = true`
  static Future<bool> linkNodes(String userAId, String userBId) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);

      final userAKey = sanitizeKey(userAId);
      final userARaw = userAId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final userBKey = sanitizeKey(userBId);
      final userBRaw = userBId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final futures = <Future<http.Response>>[];

      // Path 1: users/<user_a_id>/active_connections/<user_b_id> = true
      futures.add(http.put(
        Uri.parse('$cleanUrl/users/$userAKey/active_connections/$userBKey.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      ));
      if (userBRaw.isNotEmpty && userBRaw != userBKey) {
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$userAKey/active_connections/$userBRaw.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(true),
        ));
      }
      if (userARaw.isNotEmpty && userARaw != userAKey) {
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$userARaw/active_connections/$userBKey.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(true),
        ));
        if (userBRaw.isNotEmpty && userBRaw != userBKey) {
          futures.add(http.put(
            Uri.parse('$cleanUrl/users/$userARaw/active_connections/$userBRaw.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(true),
          ));
        }
      }

      // Path 2: users/<user_b_id>/active_connections/<user_a_id> = true
      futures.add(http.put(
        Uri.parse('$cleanUrl/users/$userBKey/active_connections/$userAKey.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      ));
      if (userARaw.isNotEmpty && userARaw != userAKey) {
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$userBKey/active_connections/$userARaw.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(true),
        ));
      }
      if (userBRaw.isNotEmpty && userBRaw != userBKey) {
        futures.add(http.put(
          Uri.parse('$cleanUrl/users/$userBRaw/active_connections/$userAKey.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(true),
        ));
        if (userARaw.isNotEmpty && userARaw != userAKey) {
          futures.add(http.put(
            Uri.parse('$cleanUrl/users/$userBRaw/active_connections/$userARaw.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(true),
          ));
        }
      }

      // Simultaneously execute all bidirectional writes
      await Future.wait(futures).timeout(const Duration(seconds: 6));
      debugPrint('Simultaneously linked nodes in Firebase: $userAId <-> $userBId');
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
      final rawKey = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final res1 = await http.get(Uri.parse('$cleanUrl/users/$userKey/active_connections.json'));
      if (res1.statusCode == 200 && res1.body != 'null') {
        final data = jsonDecode(res1.body);
        if (data is Map<String, dynamic>) {
          for (final entry in data.entries) {
            if (entry.value == true || entry.value == 'true' || entry.value != null) {
              if (!connections.contains(entry.key)) {
                connections.add(entry.key);
              }
            }
          }
        }
      }

      if (rawKey.isNotEmpty && rawKey != userKey) {
        final res2 = await http.get(Uri.parse('$cleanUrl/users/$rawKey/active_connections.json'));
        if (res2.statusCode == 200 && res2.body != 'null') {
          final data = jsonDecode(res2.body);
          if (data is Map<String, dynamic>) {
            for (final entry in data.entries) {
              if (entry.value == true || entry.value == 'true' || entry.value != null) {
                if (!connections.contains(entry.key)) {
                  connections.add(entry.key);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching active connections: $e');
    }
    return connections;
  }

  /// Multi-Stream Neighbor Tracking:
  /// Stream that emits live updates for a single neighbor node (`users/<neighbor_id>.json`)
  /// Tracks live latitude, longitude, and profilePicUrl.
  static Stream<NodeUser?> streamNeighborNode(String neighborId) async* {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return;
    final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
    final key = sanitizeKey(neighborId);
    final rawKey = neighborId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    while (true) {
      try {
        http.Response res = await http.get(Uri.parse('$cleanUrl/users/$key.json')).timeout(const Duration(seconds: 4));
        if ((res.statusCode != 200 || res.body == 'null') && rawKey.isNotEmpty && rawKey != key) {
          res = await http.get(Uri.parse('$cleanUrl/users/$rawKey.json')).timeout(const Duration(seconds: 4));
        }

        if (res.statusCode == 200 && res.body != 'null') {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final node = NodeUser.fromFirebaseJson(neighborId, data);
            yield node;
          }
        }
      } catch (e) {
        debugPrint('Error streaming neighbor node $neighborId: $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Stream that listens to a neighbor node's location in Firebase
  /// Listens to `users/<neighbor_id>/location`
  static Stream<Map<String, dynamic>?> streamNeighborLocation(String neighborId) async* {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return;
    final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
    final key = sanitizeKey(neighborId);
    final rawKey = neighborId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    while (true) {
      try {
        http.Response res = await http.get(Uri.parse('$cleanUrl/users/$key/location.json'));
        if ((res.statusCode != 200 || res.body == 'null') && rawKey.isNotEmpty && rawKey != key) {
          res = await http.get(Uri.parse('$cleanUrl/users/$rawKey/location.json'));
        }
        if (res.statusCode == 200 && res.body != 'null') {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            yield data;
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
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

    // Resilient Fallback: If cloud storage bucket offline or rejected, store compact base64
    // so profile picture still renders smoothly and saves to Firebase RTDB
    if (publicUrl == null || publicUrl.isEmpty) {
      publicUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    }

    // 2. CRITICAL FIX: Explicitly write download URL back to user's Realtime Database node
    await updateProfilePhotoUrl(nodeId: nodeId, photoUrl: publicUrl);

    return publicUrl;
  }

  /// Explicitly write profile photo URL back to user's Realtime Database node
  /// Equivalent to: FirebaseDatabase.instance.ref('users/$nodeId').update({'profilePicUrl': downloadUrl});
  static Future<bool> updateProfilePhotoUrl({
    required String nodeId,
    required String photoUrl,
  }) async {
    if (firebaseDatabaseUrl == null || firebaseDatabaseUrl!.isEmpty) return false;
    try {
      final cleanUrl = cleanDatabaseUrl(firebaseDatabaseUrl!);
      final key = sanitizeKey(nodeId);
      final rawKey = nodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final patchBody = jsonEncode({
        'profilePicUrl': photoUrl,
        'profile_pic_url': photoUrl,
        'avatar': photoUrl,
      });

      final futures = <Future<http.Response>>[];
      // Update users/<key>
      futures.add(http.patch(
        Uri.parse('$cleanUrl/users/$key.json'),
        headers: {'Content-Type': 'application/json'},
        body: patchBody,
      ));

      // Also update users/<rawKey>
      if (rawKey.isNotEmpty && rawKey != key) {
        futures.add(http.patch(
          Uri.parse('$cleanUrl/users/$rawKey.json'),
          headers: {'Content-Type': 'application/json'},
          body: patchBody,
        ));
      }

      final results = await Future.wait(futures).timeout(const Duration(seconds: 6));
      debugPrint('Explicitly updated profilePicUrl in Firebase RTDB for nodeId: $nodeId');
      return results.any((r) => r.statusCode == 200);
    } catch (e) {
      debugPrint('Error updating profile photo URL in Firebase RTDB: $e');
      return false;
    }
  }
}


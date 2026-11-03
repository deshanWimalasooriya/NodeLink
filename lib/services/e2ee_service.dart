import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart' as pc;
import 'package:pointycastle/export.dart' as pc_exp;
import 'firebase_sync_service.dart';

class E2EEService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _privKeyStorageKey = 'nodelink_e2ee_private_key_v1';
  static const String _pubKeyStorageKey = 'nodelink_e2ee_public_key_v1';

  static pc.RSAPrivateKey? _cachedPrivateKey;
  static String? _cachedPublicKeyPem;

  /// Initializes the E2EE key lifecycle.
  /// If keys exist in secure storage, loads them.
  /// If missing, generates a 2048-bit RSA key pair and securely stores them.
  /// Then publishes the public key to `users/$myNodeId/publicKey`.
  static Future<void> initKeys({required String myNodeId}) async {
    try {
      final savedPrivPem = await _secureStorage.read(key: _privKeyStorageKey);
      final savedPubPem = await _secureStorage.read(key: _pubKeyStorageKey);

      if (savedPrivPem != null && savedPubPem != null) {
        final parser = enc.RSAKeyParser();
        _cachedPrivateKey = parser.parse(savedPrivPem) as pc.RSAPrivateKey;
        _cachedPublicKeyPem = savedPubPem;
      } else {
        // Generate new 2048-bit RSA Keypair
        final pair = _generateRSAKeyPair(2048);
        _cachedPrivateKey = pair.privateKey;

        _cachedPublicKeyPem = _encodePublicKeyToPem(pair.publicKey);
        final privPem = _encodePrivateKeyToPem(pair.privateKey);

        await _secureStorage.write(key: _pubKeyStorageKey, value: _cachedPublicKeyPem);
        await _secureStorage.write(key: _privKeyStorageKey, value: privPem);
      }

      // Publish public key to Firebase Realtime Database
      if (_cachedPublicKeyPem != null && myNodeId.isNotEmpty) {
        await publishPublicKey(myNodeId: myNodeId, publicKeyPem: _cachedPublicKeyPem!);
      }
    } catch (e) {
      debugPrint('Error initializing E2EE keys: $e');
    }
  }

  /// Publish public key to Firebase RTDB at `users/<nodeId>/publicKey`
  static Future<void> publishPublicKey({
    required String myNodeId,
    required String publicKeyPem,
  }) async {
    if (FirebaseSyncService.firebaseDatabaseUrl == null) return;
    try {
      final cleanUrl = FirebaseSyncService.cleanDatabaseUrl(FirebaseSyncService.firebaseDatabaseUrl!);
      final key = FirebaseSyncService.sanitizeKey(myNodeId);
      final cleanDigits = myNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final targets = <String>{key};
      if (cleanDigits.isNotEmpty) targets.add(cleanDigits);
      if (myNodeId.isNotEmpty) targets.add(myNodeId);

      for (final targetId in targets) {
        final uri = Uri.parse('$cleanUrl/users/$targetId/publicKey.json');
        await http.put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(publicKeyPem),
        );
      }
      debugPrint('[E2EE] Public Key published for $myNodeId to paths: $targets');
    } catch (e) {
      debugPrint('Error publishing public key: $e');
    }
  }

  /// Fetches peer's RSA Public Key from `users/<peerNodeId>/publicKey.json`
  static Future<String?> fetchPeerPublicKey(String peerNodeId) async {
    if (FirebaseSyncService.firebaseDatabaseUrl == null) return null;
    try {
      final cleanUrl = FirebaseSyncService.cleanDatabaseUrl(FirebaseSyncService.firebaseDatabaseUrl!);
      final key = FirebaseSyncService.sanitizeKey(peerNodeId);
      final cleanDigits = peerNodeId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      final candidateKeys = <String>{key};
      if (cleanDigits.isNotEmpty) candidateKeys.add(cleanDigits);
      if (peerNodeId.isNotEmpty) candidateKeys.add(peerNodeId);

      for (final targetId in candidateKeys) {
        final uri = Uri.parse('$cleanUrl/users/$targetId/publicKey.json');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 && response.body != 'null' && response.body.trim().isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is String && decoded.trim().isNotEmpty) {
            return decoded.trim();
          }
        }
      }

      // Fallback: check if stored inside user node root object
      for (final targetId in candidateKeys) {
        final uri = Uri.parse('$cleanUrl/users/$targetId.json');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 && response.body != 'null') {
          final data = jsonDecode(response.body);
          if (data is Map && data['publicKey'] != null && data['publicKey'].toString().trim().isNotEmpty) {
            return data['publicKey'].toString().trim();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching peer public key for $peerNodeId: $e');
    }
    return null;
  }

  /// Encrypts plain text payload using Hybrid RSA-2048 + AES-256 (CBC)
  /// Returns a structured Map: `{'cipherText': ..., 'encryptedKey': ..., 'iv': ...}`
  static Future<Map<String, String>> encryptPayload({
    required String plainText,
    required String peerPublicKeyPem,
  }) async {
    // 1. Generate random 256-bit AES session key and 16-byte IV
    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);

    // 2. Encrypt plaintext message with AES-256
    final aesEncrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final encryptedMessage = aesEncrypter.encrypt(plainText, iv: iv);

    // 3. Parse receiver's RSA public key and encrypt the AES session key
    final parser = enc.RSAKeyParser();
    final rsaPub = parser.parse(peerPublicKeyPem) as pc.RSAPublicKey;
    final rsaEncrypter = enc.Encrypter(enc.RSA(publicKey: rsaPub));
    final encryptedAesKey = rsaEncrypter.encrypt(aesKey.base64);

    return {
      'cipherText': encryptedMessage.base64,
      'encryptedKey': encryptedAesKey.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypts encrypted payload using local RSA Private Key + AES-256
  static Future<String> decryptPayload({
    required String cipherTextBase64,
    required String encryptedKeyBase64,
    required String ivBase64,
  }) async {
    // Ensure local private key is ready
    if (_cachedPrivateKey == null) {
      final savedPrivPem = await _secureStorage.read(key: _privKeyStorageKey);
      if (savedPrivPem == null) {
        throw StateError('Cannot decrypt payload: Private key not found on device.');
      }
      final parser = enc.RSAKeyParser();
      _cachedPrivateKey = parser.parse(savedPrivPem) as pc.RSAPrivateKey;
    }

    // 1. Decrypt AES session key with RSA private key
    final rsaEncrypter = enc.Encrypter(enc.RSA(privateKey: _cachedPrivateKey));
    final decryptedAesKeyBase64 = rsaEncrypter.decrypt(enc.Encrypted.fromBase64(encryptedKeyBase64));

    // 2. Decrypt message content with AES session key and IV
    final aesKey = enc.Key.fromBase64(decryptedAesKeyBase64);
    final iv = enc.IV.fromBase64(ivBase64);
    final aesEncrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final plainText = aesEncrypter.decrypt(enc.Encrypted.fromBase64(cipherTextBase64), iv: iv);

    return plainText;
  }

  /// Computes a human-readable SHA-256 fingerprint for identity verification
  static String getPublicKeyFingerprint(String? pem) {
    if (pem == null || pem.trim().isEmpty) return 'UNVERIFIED_KEY';
    final bytes = utf8.encode(pem);
    final digest = crypto.sha256.convert(bytes);
    final hex = digest.toString().toUpperCase();
    final chunks = <String>[];
    for (int i = 0; i < hex.length && i < 32; i += 4) {
      chunks.add(hex.substring(i, min(i + 4, hex.length)));
    }
    return chunks.join(' : ');
  }

  static String? get myPublicKeyPem => _cachedPublicKeyPem;

  // -------------------------------------------------------------
  // Internal RSA Keygen & ASN.1 / PEM helper methods
  // -------------------------------------------------------------
  static pc_exp.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey> _generateRSAKeyPair(int bitLength) {
    final secureRandom = pc_exp.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(pc_exp.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = pc_exp.RSAKeyGenerator()
      ..init(pc_exp.ParametersWithRandom(
        pc_exp.RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    return pc_exp.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>(
      pair.publicKey as pc.RSAPublicKey,
      pair.privateKey as pc.RSAPrivateKey,
    );
  }

  static String _encodePublicKeyToPem(pc.RSAPublicKey publicKey) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(publicKey.modulus!));
    seq.add(ASN1Integer(publicKey.exponent!));
    final data = seq.encode();
    final b64 = base64.encode(data);
    return '-----BEGIN RSA PUBLIC KEY-----\n$b64\n-----END RSA PUBLIC KEY-----';
  }

  static String _encodePrivateKeyToPem(pc.RSAPrivateKey privateKey) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(BigInt.zero));
    seq.add(ASN1Integer(privateKey.n!));
    seq.add(ASN1Integer(privateKey.exponent!));
    seq.add(ASN1Integer(privateKey.privateExponent!));
    seq.add(ASN1Integer(privateKey.p!));
    seq.add(ASN1Integer(privateKey.q!));
    seq.add(ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)));
    seq.add(ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)));
    seq.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));
    final data = seq.encode();
    final b64 = base64.encode(data);
    return '-----BEGIN RSA PRIVATE KEY-----\n$b64\n-----END RSA PRIVATE KEY-----';
  }
}

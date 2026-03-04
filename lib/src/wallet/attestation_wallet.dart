import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

/// Manages a secp256k1 Ethereum keypair persisted in the device's secure
/// storage (Android Keystore on Android).
class AttestationWallet {
  static const String _keyPrivateKey = 'attestation_wallet_private_key';

  final FlutterSecureStorage _storage;

  AttestationWallet({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Key management
  // ---------------------------------------------------------------------------

  /// Generates a new random secp256k1 keypair and stores the private key.
  /// Returns the Ethereum address of the new key.
  Future<String> generateNewWallet() async {
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final privateKey = EthPrivateKey(keyBytes);
    final hexKey = _bytesToHex(keyBytes, include0x: true);
    await _storage.write(key: _keyPrivateKey, value: hexKey);
    return privateKey.address.hexEip55;
  }

  /// Imports an existing private key from a hex string (0x-prefixed or plain).
  /// Returns the derived Ethereum address, or throws on invalid input.
  Future<String> importPrivateKey(String hexKey) async {
    final normalised =
        hexKey.trim().startsWith('0x') ? hexKey.trim() : '0x${hexKey.trim()}';
    // Validate by constructing the key object (throws on bad input).
    final key = EthPrivateKey.fromHex(normalised);
    await _storage.write(key: _keyPrivateKey, value: normalised);
    return key.address.hexEip55;
  }

  /// Loads the stored [EthPrivateKey], or `null` if none has been saved yet.
  Future<EthPrivateKey?> loadPrivateKey() async {
    final hexKey = await _storage.read(key: _keyPrivateKey);
    if (hexKey == null) return null;
    return EthPrivateKey.fromHex(hexKey);
  }

  /// Returns the stored Ethereum address, or `null` if no wallet exists.
  Future<String?> getAddress() async {
    final key = await loadPrivateKey();
    return key?.address.hexEip55;
  }

  /// Deletes the stored keypair.
  Future<void> deleteWallet() async {
    await _storage.delete(key: _keyPrivateKey);
  }

  /// Returns `true` if a wallet is currently stored.
  Future<bool> hasWallet() async {
    final hexKey = await _storage.read(key: _keyPrivateKey);
    return hexKey != null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _bytesToHex(Uint8List bytes, {bool include0x = false}) {
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return include0x ? '0x$hex' : hex;
  }
}

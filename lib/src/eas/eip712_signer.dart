import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/crypto.dart' as eth_crypto;
import 'package:web3dart/web3dart.dart';

import '../models/location_attestation.dart';
import 'abi_encoder.dart';
import 'schema_config.dart';

/// Implements EIP-712 typed structured data signing and verification for
/// Location Protocol offchain attestations, matching the flow of the
/// Astral SDK's `OffchainSigner.signOffchainLocationAttestation`.
///
/// Signing flow:
/// 1. ABI-encode the attestation data (9 schema fields).
/// 2. Compute the EIP-712 domain separator.
/// 3. Compute the EAS struct hash (Attest v2 type).
/// 4. Compute the final digest = keccak256("\x19\x01" || domainSeparator || structHash).
/// 5. Sign the digest with secp256k1.
///
/// Verification reverses step 5 via `ecrecover`.
class EIP712Signer {
  // ---------------------------------------------------------------------------
  // EIP-712 type hashes (computed once at startup)
  // ---------------------------------------------------------------------------

  /// keccak256 of the EIP712Domain type string.
  static final Uint8List _domainTypeHash = eth_crypto.keccak256(
    Uint8List.fromList(utf8.encode(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)',
    )),
  );

  /// keccak256 of the EAS Attest v2 type string.
  static final Uint8List _attestTypeHash = eth_crypto.keccak256(
    Uint8List.fromList(utf8.encode(
      'Attest(uint16 version,bytes32 schema,address recipient,uint64 time,'
      'uint64 expirationTime,bool revocable,bytes32 refUID,bytes data)',
    )),
  );

  // ---------------------------------------------------------------------------
  // Domain separator
  // ---------------------------------------------------------------------------

  /// Computes the EIP-712 domain separator for the given [chainId] and
  /// [contractAddress].
  static Uint8List computeDomainSeparator({
    required int chainId,
    required String contractAddress,
  }) {
    final nameHash =
        eth_crypto.keccak256(Uint8List.fromList(utf8.encode('EAS')));
    final versionHash =
        eth_crypto.keccak256(Uint8List.fromList(utf8.encode('1.0.0')));

    final addr = EthereumAddress.fromHex(contractAddress);

    return eth_crypto.keccak256(_concat([
      _domainTypeHash,
      nameHash,
      versionHash,
      _encodeUint256(BigInt.from(chainId)),
      _padLeft32(addr.addressBytes),
    ]));
  }

  // ---------------------------------------------------------------------------
  // Struct hash
  // ---------------------------------------------------------------------------

  /// Computes the EAS Attest v2 struct hash from the attestation fields and
  /// the pre-hashed [encodedDataHash] = keccak256(ABI-encoded attestation data).
  static Uint8List computeStructHash({
    required Uint8List schemaUid,
    required String recipient,
    required int time,
    required int expirationTime,
    required bool revocable,
    required Uint8List encodedDataHash,
  }) {
    final recipientAddr = _resolveAddress(recipient);

    return eth_crypto.keccak256(_concat([
      _attestTypeHash,
      _encodeUint256(BigInt.from(SchemaConfig.easAttestVersion)), // uint16 as uint256
      schemaUid,
      _padLeft32(recipientAddr.addressBytes), // address → 32 bytes
      _encodeUint256(BigInt.from(time)), // uint64 as uint256
      _encodeUint256(BigInt.from(expirationTime)), // uint64 as uint256
      _encodeBool(revocable),
      Uint8List(32), // refUID = bytes32(0)
      encodedDataHash, // keccak256(data)
    ]));
  }

  // ---------------------------------------------------------------------------
  // Digest
  // ---------------------------------------------------------------------------

  /// Computes the final EIP-712 digest:
  ///   keccak256("\x19\x01" || domainSeparator || structHash)
  static Uint8List computeDigest({
    required Uint8List domainSeparator,
    required Uint8List structHash,
  }) {
    final prefix = Uint8List.fromList([0x19, 0x01]);
    return eth_crypto.keccak256(_concat([prefix, domainSeparator, structHash]));
  }

  // ---------------------------------------------------------------------------
  // Sign
  // ---------------------------------------------------------------------------

  /// Signs an [UnsignedLocationAttestation] and returns a completed
  /// [OffchainLocationAttestation].
  ///
  /// Uses Sepolia chain/contract by default; override with [chainId] and
  /// [contractAddress] for other networks.
  static OffchainLocationAttestation signLocationAttestation({
    required UnsignedLocationAttestation attestation,
    required EthPrivateKey privateKey,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = eth_crypto.keccak256(encodedData);

    final domainSeparator = computeDomainSeparator(
      chainId: chainId,
      contractAddress: contractAddress,
    );

    final structHash = computeStructHash(
      schemaUid: schemaUidBytes,
      recipient: attestation.recipient ?? _zeroAddress,
      time: attestation.eventTimestamp,
      expirationTime: attestation.expirationTime ?? 0,
      revocable: attestation.revocable,
      encodedDataHash: encodedDataHash,
    );

    final digest = computeDigest(
      domainSeparator: domainSeparator,
      structHash: structHash,
    );

    // Sign the digest using the raw secp256k1 function (synchronous).
    final rawSig = eth_crypto.sign(digest, privateKey.privateKey);
    // Adjust v: the raw sign() returns recovery id 0/1; EIP-712 uses 27/28.
    final v = rawSig.v < 27 ? rawSig.v + 27 : rawSig.v;

    final sigJson = jsonEncode({
      'v': v,
      'r': '0x${rawSig.r.toRadixString(16).padLeft(64, '0')}',
      's': '0x${rawSig.s.toRadixString(16).padLeft(64, '0')}',
    });

    // Use the digest as the attestation UID.
    final uid =
        '0x${digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    return OffchainLocationAttestation(
      eventTimestamp: attestation.eventTimestamp,
      srs: attestation.srs,
      locationType: attestation.locationType,
      location: attestation.location,
      recipeType: attestation.recipeType,
      recipePayload: attestation.recipePayload,
      mediaType: attestation.mediaType,
      mediaData: attestation.mediaData,
      memo: attestation.memo,
      recipient: attestation.recipient,
      expirationTime: attestation.expirationTime,
      revocable: attestation.revocable,
      uid: uid,
      signature: sigJson,
      signer: privateKey.address.hexEip55,
      version: SchemaConfig.attestationVersion,
    );
  }

  // ---------------------------------------------------------------------------
  // Verify
  // ---------------------------------------------------------------------------

  /// Verifies the signature on [attestation] and returns the recovered signer
  /// address.
  ///
  /// Returns `null` if the signature JSON is malformed or recovery fails.
  static String? recoverSigner({
    required OffchainLocationAttestation attestation,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    try {
      final sigMap = attestation.parsedSignature;
      final v = sigMap['v'] as int;
      final r = _parseBigInt(sigMap['r'].toString());
      final s = _parseBigInt(sigMap['s'].toString());
      final sig = MsgSignature(r, s, v);

      final digest = _recomputeDigest(
        attestation: attestation,
        chainId: chainId,
        contractAddress: contractAddress,
        schemaUid: schemaUid,
      );

      final publicKey = eth_crypto.ecRecover(digest, sig);
      return EthereumAddress.fromPublicKey(publicKey).hexEip55;
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` when the recovered signer matches [attestation.signer].
  static bool verifyLocationAttestation({
    required OffchainLocationAttestation attestation,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    final recovered = recoverSigner(
      attestation: attestation,
      chainId: chainId,
      contractAddress: contractAddress,
      schemaUid: schemaUid,
    );
    if (recovered == null) return false;
    return recovered.toLowerCase() == attestation.signer.toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Uint8List _recomputeDigest({
    required UnsignedLocationAttestation attestation,
    required int chainId,
    required String contractAddress,
    required String schemaUid,
  }) {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = eth_crypto.keccak256(encodedData);

    final domainSeparator = computeDomainSeparator(
      chainId: chainId,
      contractAddress: contractAddress,
    );

    final structHash = computeStructHash(
      schemaUid: schemaUidBytes,
      recipient: attestation.recipient ?? _zeroAddress,
      time: attestation.eventTimestamp,
      expirationTime: attestation.expirationTime ?? 0,
      revocable: attestation.revocable,
      encodedDataHash: encodedDataHash,
    );

    return computeDigest(
      domainSeparator: domainSeparator,
      structHash: structHash,
    );
  }

  static const String _zeroAddress = '0x0000000000000000000000000000000000000000';

  static EthereumAddress _resolveAddress(String hex) {
    try {
      return EthereumAddress.fromHex(hex);
    } catch (_) {
      return EthereumAddress.fromHex(_zeroAddress);
    }
  }

  static Uint8List _encodeUint256(BigInt value) {
    final bytes = Uint8List(32);
    var v = value;
    for (int i = 31; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xFF)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  static Uint8List _encodeBool(bool value) {
    final bytes = Uint8List(32);
    bytes[31] = value ? 1 : 0;
    return bytes;
  }

  static Uint8List _padLeft32(Uint8List data) {
    if (data.length == 32) return data;
    final padded = Uint8List(32);
    padded.setRange(32 - data.length, 32, data);
    return padded;
  }

  static Uint8List _hexToBytes32(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = Uint8List(32);
    for (int i = 0; i < 32 && i * 2 + 1 < clean.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static BigInt _parseBigInt(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    return BigInt.parse(clean, radix: 16);
  }

  static Uint8List _concat(List<Uint8List> parts) {
    final total = parts.fold(0, (sum, p) => sum + p.length);
    final result = Uint8List(total);
    var pos = 0;
    for (final part in parts) {
      result.setRange(pos, pos + part.length, part);
      pos += part.length;
    }
    return result;
  }
}

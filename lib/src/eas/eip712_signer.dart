import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain/on_chain.dart';

import '../models/location_attestation.dart';
import 'abi_encoder.dart';
import 'attestation_signer.dart';
import 'ecdsa_signature.dart';
import 'schema_config.dart';

/// Implements EIP-712 typed structured data signing and verification for
/// Location Protocol offchain attestations, matching the flow of the
/// EAS SDK example.
class EIP712Signer {
  static final Uint8List _domainTypeHash = _keccak256(
    utf8.encode(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)',
    ),
  );

  /// Standard EAS Attest type hash (8 core fields)
  static final Uint8List _attestTypeHash = _keccak256(
    utf8.encode(
      'Attest(uint16 version,bytes32 schema,address recipient,uint64 time,'
      'uint64 expirationTime,bool revocable,bytes32 refUID,bytes data)',
    ),
  );

  static Uint8List computeDomainSeparator({
    required int chainId,
    required String contractAddress,
  }) {
    final nameHash = _keccak256(utf8.encode(SchemaConfig.domainName));
    final versionHash = _keccak256(utf8.encode(SchemaConfig.domainVersion));
    final addr = _hexToAddressBytes(contractAddress);

    return _keccak256(_concat([
      _domainTypeHash,
      nameHash,
      versionHash,
      _encodeUint256(BigInt.from(chainId)),
      _padLeft32(addr),
    ]));
  }

  static Uint8List computeStructHash({
    required Uint8List schemaUid,
    required String recipient,
    required int time,
    required int expirationTime,
    required bool revocable,
    required Uint8List encodedDataHash,
  }) {
    final recipientAddr = _resolveAddressBytes(recipient);

    return _keccak256(_concat([
      _attestTypeHash,
      _encodeUint256(BigInt.from(SchemaConfig.easAttestVersion)),
      schemaUid,
      _padLeft32(recipientAddr),
      _encodeUint256(BigInt.from(time)),
      _encodeUint256(BigInt.from(expirationTime)),
      _encodeBool(revocable),
      Uint8List(32), // refUID = bytes32(0)
      encodedDataHash,
    ]));
  }

  static Uint8List computeDigest({
    required Uint8List domainSeparator,
    required Uint8List structHash,
  }) {
    final prefix = Uint8List.fromList([0x19, 0x01]);
    return _keccak256(_concat([prefix, domainSeparator, structHash]));
  }

  static OffchainLocationAttestation signLocationAttestation({
    required UnsignedLocationAttestation attestation,
    required String privateKeyHex,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = _keccak256(encodedData);
    final key = ETHPrivateKey(privateKeyHex);
    final signerAddress = key.publicKey().toAddress().address;

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

    final raw = key.sign(digest, hashMessage: false);
    final v = raw.v < 27 ? raw.v + 27 : raw.v;

    final sigJson = jsonEncode({
      'v': v,
      'r': '0x${BytesUtils.toHexString(raw.rBytes).padLeft(64, '0')}',
      's': '0x${BytesUtils.toHexString(raw.sBytes).padLeft(64, '0')}',
    });

    final encodedDataHex = '0x${encodedData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final uid = computeOffchainUid(
      version: SchemaConfig.easAttestVersion,
      schemaUid: schemaUid,
      recipient: attestation.recipient ?? _zeroAddress,
      time: attestation.eventTimestamp,
      expirationTime: attestation.expirationTime ?? 0,
      revocable: attestation.revocable,
      refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
      data: encodedDataHex,
    );

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
      signer: signerAddress,
      version: SchemaConfig.attestationVersion,
    );
  }

  /// Async version of [signLocationAttestation] that accepts any
  /// [AttestationSigner] implementation instead of a raw private key.
  ///
  /// Use this with `PrivySignerAdapter` for Privy embedded wallets,
  /// or [LocalKeySigner] for raw key signing.
  ///
  /// Calls [AttestationSigner.signTypedData] so that wallet implementations
  /// (e.g. Privy) can use `eth_signTypedData_v4` directly.  [LocalKeySigner]
  /// falls back to signing the pre-computed EIP-712 digest, which produces
  /// an identical result.
  static Future<OffchainLocationAttestation> signLocationAttestationWith({
    required UnsignedLocationAttestation attestation,
    required AttestationSigner signer,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) async {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = _keccak256(encodedData);
    final signerAddress = signer.address;

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

    // Build the EIP-712 typed-data maps so wallet implementations can pass
    // them directly to eth_signTypedData_v4.
    final encodedDataHex =
        '0x${encodedData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    final domain = {
      'name': SchemaConfig.domainName,
      'version': SchemaConfig.domainVersion,
      'chainId': chainId,
      'verifyingContract': contractAddress,
    };

    final types = {
      'Attest': [
        {'name': 'version', 'type': 'uint16'},
        {'name': 'schema', 'type': 'bytes32'},
        {'name': 'recipient', 'type': 'address'},
        {'name': 'time', 'type': 'uint64'},
        {'name': 'expirationTime', 'type': 'uint64'},
        {'name': 'revocable', 'type': 'bool'},
        {'name': 'refUID', 'type': 'bytes32'},
        {'name': 'data', 'type': 'bytes'},
      ],
    };

    final message = {
      'version': SchemaConfig.easAttestVersion,
      'schema': schemaUid,
      'recipient': attestation.recipient ?? _zeroAddress,
      'time': attestation.eventTimestamp.toString(),
      'expirationTime': (attestation.expirationTime ?? 0).toString(),
      'revocable': attestation.revocable,
      'refUID':
          '0x0000000000000000000000000000000000000000000000000000000000000000',
      'data': encodedDataHex,
      'nonce': '0',
    };

    final rawSig = await signer.signTypedData(
      domain: domain,
      types: types,
      message: message,
      precomputedDigest: digest,
    );
    final v = rawSig.v < 27 ? rawSig.v + 27 : rawSig.v;

    final sigJson = jsonEncode({
      'v': v,
      'r': '0x${rawSig.r.toRadixString(16).padLeft(64, '0')}',
      's': '0x${rawSig.s.toRadixString(16).padLeft(64, '0')}',
    });

    final uid = computeOffchainUid(
      version: SchemaConfig.easAttestVersion,
      schemaUid: schemaUid,
      recipient: attestation.recipient ?? _zeroAddress,
      time: attestation.eventTimestamp,
      expirationTime: attestation.expirationTime ?? 0,
      revocable: attestation.revocable,
      refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
      data: encodedDataHex,
    );

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
      signer: signerAddress,
      version: SchemaConfig.attestationVersion,
    );
  }

  static String? recoverSigner({
    required OffchainLocationAttestation attestation,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    try {
      final sigMap = attestation.parsedSignature;
      final v = (sigMap['v'] as int) - 27; // stored as 27/28; on_chain expects 0/1
      final r = _hexToBytes((sigMap['r'] as String).substring(2));
      final s = _hexToBytes((sigMap['s'] as String).substring(2));

      final digest = _recomputeDigest(
        attestation: attestation,
        chainId: chainId,
        contractAddress: contractAddress,
        schemaUid: schemaUid,
      );

      // Build 65-byte sig: r (32 bytes, left-padded) || s (32 bytes, left-padded) || v (1 byte)
      final sigBytes = <int>[
        ...List<int>.filled(32 - r.length, 0),
        ...r,
        ...List<int>.filled(32 - s.length, 0),
        ...s,
        v,
      ];

      final pubKey =
          ETHPublicKey.getPublicKey(digest, sigBytes, hashMessage: false);
      if (pubKey == null) return null;
      return pubKey.toAddress().address;
    } catch (_) {
      return null;
    }
  }

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
    return recovered != null && recovered.toLowerCase() == attestation.signer.toLowerCase();
  }

  static Uint8List _recomputeDigest({
    required OffchainLocationAttestation attestation,
    required int chainId,
    required String contractAddress,
    required String schemaUid,
  }) {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = _keccak256(encodedData);

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

  /// Computes the offchain UID matching the EAS SDK's
  /// `solidityPackedKeccak256` for Version1 attestations.
  ///
  /// This uses Solidity's `abi.encodePacked` (tightly packed, no padding)
  /// followed by keccak256, matching:
  /// ```
  /// solidityPackedKeccak256(
  ///   ['uint16','bytes','address','address','uint64','uint64','bool','bytes32','bytes','uint32'],
  ///   [version, hexlify(toUtf8Bytes(schema)), recipient, ZERO_ADDRESS,
  ///    time, expirationTime, revocable, refUID, data, 0]
  /// )
  /// ```
  static String computeOffchainUid({
    required int version,
    required String schemaUid,
    required String recipient,
    required int time,
    required int expirationTime,
    required bool revocable,
    required String refUID,
    required String data,
    int nonce = 0,
  }) {
    final packed = _concat([
      _packUint16(version),
      // EAS SDK does: hexlify(toUtf8Bytes(schema))
      // toUtf8Bytes converts the schema string to UTF-8 bytes,
      // hexlify then makes it a hex string. But solidityPackedKeccak256
      // with type 'bytes' takes those raw bytes from the hex string.
      // So the net effect is: UTF-8 encode the schema string, then
      // hexlify, then unhexlify for packing = just UTF-8 bytes of the schema.
      Uint8List.fromList(utf8.encode(schemaUid)),
      _packAddress(recipient),
      _packAddress(_zeroAddress), // attester placeholder (ZERO_ADDRESS in SDK)
      _packUint64(time),
      _packUint64(expirationTime),
      _packBool(revocable),
      _hexToBytes32(refUID),
      _hexToBytes(data),
      _packUint32(nonce),
    ]);
    final hash = _keccak256(packed);
    return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  // ---------------------------------------------------------------------------
  // Crypto helper
  // ---------------------------------------------------------------------------

  /// Computes keccak-256 of [input] and returns a 32-byte [Uint8List].
  static Uint8List _keccak256(List<int> input) =>
      Uint8List.fromList(QuickCrypto.keccack256Hash(input));

  // ---------------------------------------------------------------------------
  // Encoding / byte helpers
  // ---------------------------------------------------------------------------

  static const String _zeroAddress = '0x0000000000000000000000000000000000000000';

  static Uint8List _resolveAddressBytes(String hex) {
    try {
      return _hexToAddressBytes(hex);
    } catch (_) {
      return _hexToAddressBytes(_zeroAddress);
    }
  }

  static Uint8List _hexToAddressBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.length != 40) {
      throw FormatException('Address must be 20 bytes (40 hex chars).');
    }
    final bytes = Uint8List(20);
    for (int i = 0; i < 20; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
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

  /// Decodes a hex string (0x-prefixed or plain) to raw bytes.
  static Uint8List _hexToBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.isEmpty) return Uint8List(0);
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Solidity abi.encodePacked helpers (tightly packed, no 32-byte padding)
  // ---------------------------------------------------------------------------

  static Uint8List _packUint16(int value) {
    final bytes = Uint8List(2);
    bytes[0] = (value >> 8) & 0xFF;
    bytes[1] = value & 0xFF;
    return bytes;
  }

  static Uint8List _packUint32(int value) {
    final bytes = Uint8List(4);
    bytes[0] = (value >> 24) & 0xFF;
    bytes[1] = (value >> 16) & 0xFF;
    bytes[2] = (value >> 8) & 0xFF;
    bytes[3] = value & 0xFF;
    return bytes;
  }

  static Uint8List _packUint64(int value) {
    final bytes = Uint8List(8);
    var v = value;
    for (int i = 7; i >= 0; i--) {
      bytes[i] = v & 0xFF;
      v = v >> 8;
    }
    return bytes;
  }

  static Uint8List _packAddress(String hex) {
    return _hexToAddressBytes(hex); // 20 bytes
  }

  static Uint8List _packBool(bool value) {
    return Uint8List.fromList([value ? 1 : 0]);
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


/// Implements EIP-712 typed structured data signing and verification for
/// Location Protocol offchain attestations, matching the flow of the
/// EAS SDK example.
class EIP712Signer {
  static final Uint8List _domainTypeHash = keccak256(
    Uint8List.fromList(utf8.encode(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)',
    )),
  );

  /// Standard EAS Attest type hash (8 core fields)
  static final Uint8List _attestTypeHash = keccak256(
    Uint8List.fromList(utf8.encode(
      'Attest(uint16 version,bytes32 schema,address recipient,uint64 time,'
      'uint64 expirationTime,bool revocable,bytes32 refUID,bytes data)',
    )),
  );

  static Uint8List computeDomainSeparator({
    required int chainId,
    required String contractAddress,
  }) {
    final nameHash = keccak256(Uint8List.fromList(utf8.encode(SchemaConfig.domainName)));
    final versionHash = keccak256(Uint8List.fromList(utf8.encode(SchemaConfig.domainVersion)));
    final addr = _hexToAddressBytes(contractAddress);

    return keccak256(_concat([
      _domainTypeHash,
      nameHash,
      versionHash,
      _encodeUint256(BigInt.from(chainId)),
      _padLeft32(addr),
    ]));
  }

  static Uint8List computeStructHash({
    required Uint8List schemaUid,
    required String recipient,
    required int time,
    required int expirationTime,
    required bool revocable,
    required Uint8List encodedDataHash,
  }) {
    final recipientAddr = _resolveAddressBytes(recipient);

    return keccak256(_concat([
      _attestTypeHash,
      _encodeUint256(BigInt.from(SchemaConfig.easAttestVersion)),
      schemaUid,
      _padLeft32(recipientAddr),
      _encodeUint256(BigInt.from(time)),
      _encodeUint256(BigInt.from(expirationTime)),
      _encodeBool(revocable),
      Uint8List(32), // refUID = bytes32(0)
      encodedDataHash,
    ]));
  }

  static Uint8List computeDigest({
    required Uint8List domainSeparator,
    required Uint8List structHash,
  }) {
    final prefix = Uint8List.fromList([0x19, 0x01]);
    return keccak256(_concat([prefix, domainSeparator, structHash]));
  }

  static OffchainLocationAttestation signLocationAttestation({
    required UnsignedLocationAttestation attestation,
    required EthPrivateKey privateKey,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = keccak256(encodedData);
    final signerAddress = privateKey.address.eip55With0x;

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

    final rawSig = sign(digest, privateKey.privateKey);
    final v = rawSig.v < 27 ? rawSig.v + 27 : rawSig.v;

    final sigJson = jsonEncode({
      'v': v,
      'r': '0x${rawSig.r.toRadixString(16).padLeft(64, '0')}',
      's': '0x${rawSig.s.toRadixString(16).padLeft(64, '0')}',
    });

    final encodedDataHex = '0x${encodedData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final uid = computeOffchainUid(
      version: SchemaConfig.easAttestVersion,
      schemaUid: schemaUid,
      recipient: attestation.recipient ?? _zeroAddress,
      time: attestation.eventTimestamp,
      expirationTime: attestation.expirationTime ?? 0,
      revocable: attestation.revocable,
      refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
      data: encodedDataHex,
    );

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
      signer: signerAddress,
      version: SchemaConfig.attestationVersion,
    );
  }

  /// Async version of [signLocationAttestation] that accepts any
  /// [AttestationSigner] implementation instead of a raw private key.
  ///
  /// Use this with `PrivySignerAdapter` for Privy embedded wallets,
  /// or [LocalKeySigner] for raw key signing.
  ///
  /// Calls [AttestationSigner.signTypedData] so that wallet implementations
  /// (e.g. Privy) can use `eth_signTypedData_v4` directly.  [LocalKeySigner]
  /// falls back to signing the pre-computed EIP-712 digest, which produces
  /// an identical result.
  static Future<OffchainLocationAttestation> signLocationAttestationWith({
    required UnsignedLocationAttestation attestation,
    required AttestationSigner signer,
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) async {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = keccak256(encodedData);
    final signerAddress = signer.address;

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

    // Build the EIP-712 typed-data maps so wallet implementations can pass
    // them directly to eth_signTypedData_v4.
    final encodedDataHex =
        '0x${encodedData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    final domain = {
      'name': SchemaConfig.domainName,
      'version': SchemaConfig.domainVersion,
      'chainId': chainId,
      'verifyingContract': contractAddress,
    };

    final types = {
      'Attest': [
        {'name': 'version', 'type': 'uint16'},
        {'name': 'schema', 'type': 'bytes32'},
        {'name': 'recipient', 'type': 'address'},
        {'name': 'time', 'type': 'uint64'},
        {'name': 'expirationTime', 'type': 'uint64'},
        {'name': 'revocable', 'type': 'bool'},
        {'name': 'refUID', 'type': 'bytes32'},
        {'name': 'data', 'type': 'bytes'},
      ],
    };

    final message = {
      'version': SchemaConfig.easAttestVersion,
      'schema': schemaUid,
      'recipient': attestation.recipient ?? _zeroAddress,
      'time': attestation.eventTimestamp.toString(),
      'expirationTime': (attestation.expirationTime ?? 0).toString(),
      'revocable': attestation.revocable,
      'refUID':
          '0x0000000000000000000000000000000000000000000000000000000000000000',
      'data': encodedDataHex,
      'nonce': '0',
    };

    final rawSig = await signer.signTypedData(
      domain: domain,
      types: types,
      message: message,
      precomputedDigest: digest,
    );
    final v = rawSig.v < 27 ? rawSig.v + 27 : rawSig.v;

    final sigJson = jsonEncode({
      'v': v,
      'r': '0x${rawSig.r.toRadixString(16).padLeft(64, '0')}',
      's': '0x${rawSig.s.toRadixString(16).padLeft(64, '0')}',
    });

    final uid = computeOffchainUid(
      version: SchemaConfig.easAttestVersion,
      schemaUid: schemaUid,
      recipient: attestation.recipient ?? _zeroAddress,
      time: attestation.eventTimestamp,
      expirationTime: attestation.expirationTime ?? 0,
      revocable: attestation.revocable,
      refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
      data: encodedDataHex,
    );

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
      signer: signerAddress,
      version: SchemaConfig.attestationVersion,
    );
  }

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

      final publicKey = ecRecover(digest, sig);
      return bytesToHex(publicKeyToAddress(publicKey), include0x: true);
    } catch (_) {
      return null;
    }
  }

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
    return recovered != null && recovered.toLowerCase() == attestation.signer.toLowerCase();
  }

  static Uint8List _recomputeDigest({
    required OffchainLocationAttestation attestation,
    required int chainId,
    required String contractAddress,
    required String schemaUid,
  }) {
    final schemaUidBytes = _hexToBytes32(schemaUid);
    final encodedData = AbiEncoder.encodeAttestationData(attestation);
    final encodedDataHash = keccak256(encodedData);

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

  /// Computes the offchain UID matching the EAS SDK's
  /// `solidityPackedKeccak256` for Version1 attestations.
  ///
  /// This uses Solidity's `abi.encodePacked` (tightly packed, no padding)
  /// followed by keccak256, matching:
  /// ```
  /// solidityPackedKeccak256(
  ///   ['uint16','bytes','address','address','uint64','uint64','bool','bytes32','bytes','uint32'],
  ///   [version, hexlify(toUtf8Bytes(schema)), recipient, ZERO_ADDRESS,
  ///    time, expirationTime, revocable, refUID, data, 0]
  /// )
  /// ```
  static String computeOffchainUid({
    required int version,
    required String schemaUid,
    required String recipient,
    required int time,
    required int expirationTime,
    required bool revocable,
    required String refUID,
    required String data,
    int nonce = 0,
  }) {
    final packed = _concat([
      _packUint16(version),
      // EAS SDK does: hexlify(toUtf8Bytes(schema))
      // toUtf8Bytes converts the schema string to UTF-8 bytes,
      // hexlify then makes it a hex string. But solidityPackedKeccak256
      // with type 'bytes' takes those raw bytes from the hex string.
      // So the net effect is: UTF-8 encode the schema string, then
      // hexlify, then unhexlify for packing = just UTF-8 bytes of the schema.
      Uint8List.fromList(utf8.encode(schemaUid)),
      _packAddress(recipient),
      _packAddress(_zeroAddress), // attester placeholder (ZERO_ADDRESS in SDK)
      _packUint64(time),
      _packUint64(expirationTime),
      _packBool(revocable),
      _hexToBytes32(refUID),
      _hexToBytes(data),
      _packUint32(nonce),
    ]);
    final hash = keccak256(packed);
    return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static const String _zeroAddress = '0x0000000000000000000000000000000000000000';

  static Uint8List _resolveAddressBytes(String hex) {
    try {
      return _hexToAddressBytes(hex);
    } catch (_) {
      return _hexToAddressBytes(_zeroAddress);
    }
  }

  static Uint8List _hexToAddressBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.length != 40) {
      throw FormatException('Address must be 20 bytes (40 hex chars).');
    }
    final bytes = Uint8List(20);
    for (int i = 0; i < 20; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
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

  /// Decodes a hex string (0x-prefixed or plain) to raw bytes.
  static Uint8List _hexToBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.isEmpty) return Uint8List(0);
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static BigInt _parseBigInt(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    return BigInt.parse(clean, radix: 16);
  }

  // ---------------------------------------------------------------------------
  // Solidity abi.encodePacked helpers (tightly packed, no 32-byte padding)
  // ---------------------------------------------------------------------------

  static Uint8List _packUint16(int value) {
    final bytes = Uint8List(2);
    bytes[0] = (value >> 8) & 0xFF;
    bytes[1] = value & 0xFF;
    return bytes;
  }

  static Uint8List _packUint32(int value) {
    final bytes = Uint8List(4);
    bytes[0] = (value >> 24) & 0xFF;
    bytes[1] = (value >> 16) & 0xFF;
    bytes[2] = (value >> 8) & 0xFF;
    bytes[3] = value & 0xFF;
    return bytes;
  }

  static Uint8List _packUint64(int value) {
    final bytes = Uint8List(8);
    var v = value;
    for (int i = 7; i >= 0; i--) {
      bytes[i] = v & 0xFF;
      v = v >> 8;
    }
    return bytes;
  }

  static Uint8List _packAddress(String hex) {
    return _hexToAddressBytes(hex); // 20 bytes
  }

  static Uint8List _packBool(bool value) {
    return Uint8List.fromList([value ? 1 : 0]);
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

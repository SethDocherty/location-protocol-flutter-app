import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'package:location_protocol_flutter_app/src/builder/attestation_builder.dart';
import 'package:location_protocol_flutter_app/src/eas/abi_encoder.dart';
import 'package:location_protocol_flutter_app/src/eas/attestation_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/eip712_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/privy_signer_adapter.dart';

/// Well-known Hardhat test account #0 — used across the test suite as a
/// deterministic signing key so we can cross-check adapter output against
/// direct web3dart signatures.
const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

/// Returns a 0x-prefixed 65-byte hex signature for [digest] signed by
/// [privateKey], in the r || s || v byte order expected by the Privy adapter.
String _signDigestAsHex(Uint8List digest, EthPrivateKey privateKey) {
  final raw = sign(digest, privateKey.privateKey);
  final v = raw.v < 27 ? raw.v + 27 : raw.v;
  final r = raw.r.toRadixString(16).padLeft(64, '0');
  final s = raw.s.toRadixString(16).padLeft(64, '0');
  final vHex = v.toRadixString(16).padLeft(2, '0');
  return '0x$r$s$vHex';
}

void main() {
  group('PrivySignerAdapter — interface contract', () {
    late PrivySignerAdapter adapter;

    setUp(() {
      adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async =>
            // dummy 65-byte signature (all zeros); tests in this group never
            // exercise the actual RPC call
            '0x${'00' * 65}',
      );
    });

    test('implements AttestationSigner', () {
      expect(adapter, isA<AttestationSigner>());
    });

    test('returns the address supplied at construction', () {
      expect(adapter.address, _testAddress);
    });
  });

  // ---------------------------------------------------------------------------
  // signTypedData — RPC routing and payload shape
  // ---------------------------------------------------------------------------

  group('PrivySignerAdapter.signTypedData', () {
    test('calls eth_signTypedData_v4', () async {
      String? capturedMethod;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (method, _) async {
          capturedMethod = method;
          return '0x${'ab' * 32}${'cd' * 32}1b'; // valid 65-byte sig
        },
      );

      await adapter.signTypedData(
        domain: {'name': 'Test', 'version': '1', 'chainId': 1},
        types: {},
        message: {},
        precomputedDigest: Uint8List(32),
      );

      expect(capturedMethod, 'eth_signTypedData_v4');
    });

    test('passes signer address as first RPC param', () async {
      String? capturedAddress;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, params) async {
          capturedAddress = params[0] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await adapter.signTypedData(
        domain: {},
        types: {},
        message: {},
        precomputedDigest: Uint8List(32),
      );

      expect(capturedAddress, _testAddress);
    });

    test('typed-data JSON includes EIP712Domain in types', () async {
      Map<String, dynamic>? capturedPayload;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, params) async {
          capturedPayload = jsonDecode(params[1] as String)
              as Map<String, dynamic>;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await adapter.signTypedData(
        domain: {'name': 'EAS Attestation', 'version': '0.26', 'chainId': 11155111},
        types: {
          'Attest': [
            {'name': 'version', 'type': 'uint16'},
          ],
        },
        message: {'version': '1'},
        precomputedDigest: Uint8List(32),
      );

      final types = capturedPayload!['types'] as Map<String, dynamic>;
      expect(types.containsKey('EIP712Domain'), isTrue,
          reason: 'EIP712Domain must be present in the typed-data types map');
      expect(types.containsKey('Attest'), isTrue,
          reason: 'Caller-supplied types must be preserved');
    });

    test('typed-data JSON uses primary_type (snake_case) for Privy SDK', () async {
      Map<String, dynamic>? capturedPayload;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, params) async {
          capturedPayload = jsonDecode(params[1] as String)
              as Map<String, dynamic>;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await adapter.signTypedData(
        domain: {},
        types: {},
        message: {},
        precomputedDigest: Uint8List(32),
      );

      expect(capturedPayload!.containsKey('primary_type'), isTrue,
          reason: 'Privy SDK requires snake_case primary_type');
      expect(capturedPayload!.containsKey('primaryType'), isFalse,
          reason: 'camelCase primaryType is for browser wallets, not Privy SDK');
    });

    test('precomputedDigest is intentionally not sent to the wallet', () async {
      final sentinel = Uint8List.fromList(List.generate(32, (i) => i + 1));
      String? capturedJson;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, params) async {
          capturedJson = params[1] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await adapter.signTypedData(
        domain: {},
        types: {},
        message: {},
        precomputedDigest: sentinel,
      );

      // The sentinel bytes must NOT appear in the JSON payload — the wallet
      // must recompute the hash from the typed data, not sign a raw digest.
      final sentinelHex = sentinel.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(capturedJson!.contains(sentinelHex), isFalse,
          reason: 'precomputedDigest must not be forwarded to the wallet');
    });
  });

  // ---------------------------------------------------------------------------
  // signDigest — RPC routing
  // ---------------------------------------------------------------------------

  group('PrivySignerAdapter.signDigest', () {
    test('calls personal_sign', () async {
      String? capturedMethod;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (method, _) async {
          capturedMethod = method;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      final digest = keccak256(Uint8List.fromList([1, 2, 3]));
      await adapter.signDigest(digest);

      expect(capturedMethod, 'personal_sign');
    });

    test('passes 0x-prefixed hex digest as first personal_sign param', () async {
      List<dynamic>? capturedParams;

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, params) async {
          capturedParams = params;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      final digest = Uint8List.fromList(List.generate(32, (i) => i));
      await adapter.signDigest(digest);

      final digestHex = capturedParams![0] as String;
      expect(digestHex, startsWith('0x'));
      // Each byte is 2 hex chars, plus the '0x' prefix = 66 chars total.
      expect(digestHex.length, 66,
          reason: 'Expected 32-byte (64 hex char) 0x-prefixed digest');
    });
  });

  // ---------------------------------------------------------------------------
  // Signature parsing
  // ---------------------------------------------------------------------------

  group('PrivySignerAdapter — signature parsing', () {
    PrivySignerAdapter _adapterWith(String sigHex) {
      return PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async => sigHex,
      );
    }

    test('parses a valid 65-byte 0x-prefixed signature', () async {
      // Use a known valid-length signature (r=0xaa…, s=0xbb…, v=0x1b=27).
      final sigHex = '0x${'aa' * 32}${'bb' * 32}1b';
      final adapter = _adapterWith(sigHex);

      final sig = await adapter.signDigest(Uint8List(32));

      expect(sig.r, BigInt.parse('aa' * 32, radix: 16));
      expect(sig.s, BigInt.parse('bb' * 32, radix: 16));
      expect(sig.v, 27);
    });

    test('accepts signature without 0x prefix', () async {
      final sigHex = '${'aa' * 32}${'bb' * 32}1c'; // no 0x prefix, v=28
      final adapter = _adapterWith(sigHex);

      final sig = await adapter.signDigest(Uint8List(32));
      expect(sig.v, 28);
    });

    test('normalises v=0 to 27 (compact Ethereum encoding)', () async {
      final sigHex = '0x${'aa' * 32}${'bb' * 32}00'; // v=0 → should become 27
      final adapter = _adapterWith(sigHex);

      final sig = await adapter.signDigest(Uint8List(32));
      expect(sig.v, 27);
    });

    test('normalises v=1 to 28 (compact Ethereum encoding)', () async {
      final sigHex = '0x${'aa' * 32}${'bb' * 32}01'; // v=1 → should become 28
      final adapter = _adapterWith(sigHex);

      final sig = await adapter.signDigest(Uint8List(32));
      expect(sig.v, 28);
    });

    test('keeps v=27 unchanged', () async {
      final sigHex = '0x${'aa' * 32}${'bb' * 32}1b'; // v=27 → stays 27
      final adapter = _adapterWith(sigHex);

      final sig = await adapter.signDigest(Uint8List(32));
      expect(sig.v, 27);
    });

    test('keeps v=28 unchanged', () async {
      final sigHex = '0x${'aa' * 32}${'bb' * 32}1c'; // v=28 → stays 28
      final adapter = _adapterWith(sigHex);

      final sig = await adapter.signDigest(Uint8List(32));
      expect(sig.v, 28);
    });
  });

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  group('PrivySignerAdapter — error handling', () {
    test('throws PrivySigningException when RPC caller throws it', () {
      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async =>
            throw const PrivySigningException('user rejected'),
      );

      expect(
        adapter.signDigest(Uint8List(32)),
        throwsA(isA<PrivySigningException>()),
      );
    });

    test('throws PrivySigningException when RPC caller throws generic error', () {
      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async => throw Exception('network timeout'),
      );

      expect(
        adapter.signDigest(Uint8List(32)),
        throwsA(isA<Exception>()),
      );
    });

    test('throws FormatException for signature shorter than 65 bytes', () {
      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async => '0xdeadbeef', // only 4 bytes
      );

      expect(
        adapter.signDigest(Uint8List(32)),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for signature longer than 65 bytes', () {
      final adapter = PrivySignerAdapter(
        address: _testAddress,
        // 66 bytes = 132 hex chars
        rpcCaller: (_, __) async => '0x${'aa' * 66}',
      );

      expect(
        adapter.signDigest(Uint8List(32)),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty signature', () {
      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async => '',
      );

      expect(
        adapter.signDigest(Uint8List(32)),
        throwsA(isA<FormatException>()),
      );
    });

    test('PrivySigningException.toString includes message', () {
      const ex = PrivySigningException('something went wrong');
      expect(ex.toString(), contains('something went wrong'));
      expect(ex.toString(), contains('PrivySigningException'));
    });
  });

  // ---------------------------------------------------------------------------
  // End-to-end: sign via adapter → verify via EIP712Signer
  // ---------------------------------------------------------------------------

  group('PrivySignerAdapter — end-to-end signing + verification', () {
    late EthPrivateKey privateKey;

    setUp(() {
      privateKey = EthPrivateKey.fromHex(_testPrivateKey);
    });

    /// Builds a mock [PrivySignerAdapter] whose RPC caller simulates the
    /// behaviour of `eth_signTypedData_v4`:
    ///
    /// It receives the EIP-712 typed-data JSON and uses the pre-computed
    /// digest (captured via closure) to produce a signature using the
    /// test private key.  This mirrors what a real Privy wallet does
    /// (compute the EIP-712 hash and sign it), letting us verify the
    /// full adapter→protocol-library round trip in a unit test.
    PrivySignerAdapter _mockAdapterThatSignsDigest(Uint8List digest) {
      return PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async => _signDigestAsHex(digest, privateKey),
      );
    }

    test('signed attestation verifies via EIP712Signer.verifyLocationAttestation',
        () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Privy adapter test',
        eventTimestamp: 1700000000,
      );

      // Pre-compute the EIP-712 digest so the mock can sign it correctly.
      final encodedData = AbiEncoder.encodeAttestationData(unsigned);
      final encodedDataHash = keccak256(encodedData);
      final domainSeparator = EIP712Signer.computeDomainSeparator(
        chainId: 11155111,
        contractAddress: '0xC2679fBD37d54388Ce493F1DB75320D236e1815e',
      );
      final structHash = EIP712Signer.computeStructHash(
        schemaUid: _hexToBytes32(
            '0xba4171c92572b1e4f241d044c32cdf083be9fd946b8766977558ca6378c824e2'),
        recipient: '0x0000000000000000000000000000000000000000',
        time: unsigned.eventTimestamp,
        expirationTime: 0,
        revocable: unsigned.revocable,
        encodedDataHash: encodedDataHash,
      );
      final digest = EIP712Signer.computeDigest(
        domainSeparator: domainSeparator,
        structHash: structHash,
      );

      final adapter = _mockAdapterThatSignsDigest(digest);

      final signed = await EIP712Signer.signLocationAttestationWith(
        attestation: unsigned,
        signer: adapter,
      );

      expect(signed.signer.toLowerCase(), _testAddress.toLowerCase());
      expect(
        EIP712Signer.verifyLocationAttestation(attestation: signed),
        isTrue,
        reason: 'Attestation signed via PrivySignerAdapter must verify',
      );
    });

    test('adapter output matches direct LocalKeySigner output', () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 51.5074,
        longitude: -0.1278,
        memo: 'Parity test',
        eventTimestamp: 1700000100,
      );

      // Sign directly with the private key (existing synchronous path).
      final directSigned = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );

      // Extract the same signature for the mock to return.
      final sigMap = directSigned.parsedSignature;
      final v = (sigMap['v'] as int).toRadixString(16).padLeft(2, '0');
      final r = (sigMap['r'] as String).substring(2); // strip 0x
      final s = (sigMap['s'] as String).substring(2); // strip 0x
      final sigHex = '0x$r$s$v';

      final adapter = PrivySignerAdapter(
        address: _testAddress,
        rpcCaller: (_, __) async => sigHex,
      );

      final adapterSigned = await EIP712Signer.signLocationAttestationWith(
        attestation: unsigned,
        signer: adapter,
      );

      // Both paths must produce the same UID and a verifiable attestation.
      expect(adapterSigned.uid, directSigned.uid,
          reason: 'UIDs must match — same payload, same signer');
      expect(
        EIP712Signer.verifyLocationAttestation(attestation: adapterSigned),
        isTrue,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Local test helpers (mirror private helpers from eip712_signer.dart)
// ---------------------------------------------------------------------------

/// Decodes a 0x-prefixed 32-byte hex string to a [Uint8List].
Uint8List _hexToBytes32(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  final bytes = Uint8List(32);
  for (int i = 0; i < 32 && i * 2 + 1 < clean.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

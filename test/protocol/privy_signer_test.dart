import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/privy_signer.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

/// Well-known Hardhat test account #0.
const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('PrivySigner — interface contract', () {
    late PrivySigner signer;

    setUp(() {
      signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => '0x${'00' * 65}',
      );
    });

    test('extends Signer', () {
      expect(signer, isA<Signer>());
    });

    test('returns the address supplied at construction', () {
      expect(signer.address, _testAddress);
    });
  });

  group('PrivySigner.signTypedData', () {
    test('calls eth_signTypedData_v4 via rpcCaller', () async {
      String? capturedMethod;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, _) async {
          capturedMethod = method;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await signer.signTypedData({
        'domain': {'name': 'Test'},
        'types': {},
        'primaryType': 'Test',
        'message': {},
      });

      expect(capturedMethod, 'eth_signTypedData_v4');
    });

    test('passes signer address as first param', () async {
      String? capturedAddress;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, params) async {
          capturedAddress = params[0] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await signer.signTypedData({'domain': {}, 'types': {}, 'message': {}});
      expect(capturedAddress, _testAddress);
    });

    test('passes JSON-encoded typed data as second param', () async {
      String? capturedJson;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, params) async {
          capturedJson = params[1] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      final typedData = {
        'domain': {'name': 'EAS'},
        'types': {'Attest': []},
        'primaryType': 'Attest',
        'message': {'version': 1},
      };
      await signer.signTypedData(typedData);

      final decoded = jsonDecode(capturedJson!) as Map<String, dynamic>;
      expect(decoded['domain']['name'], 'EAS');
    });

    test('remaps primaryType to primary_type for Privy Android SDK', () async {
      String? capturedJson;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, params) async {
          capturedJson = params[1] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await signer.signTypedData({
        'domain': {'name': 'EAS Attestation'},
        'types': {'Attest': []},
        'primaryType': 'Attest',
        'message': {'version': '2'},
      });

      final decoded = jsonDecode(capturedJson!) as Map<String, dynamic>;
      // Privy Android SDK requires snake_case 'primary_type', not camelCase.
      expect(decoded.containsKey('primary_type'), isTrue,
          reason: 'Privy Android SDK requires primary_type (snake_case)');
      expect(decoded.containsKey('primaryType'), isFalse,
          reason: 'primaryType (camelCase) must be removed');
      expect(decoded['primary_type'], 'Attest');
    });

    test('returns EIP712Signature parsed from hex response', () async {
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => '0x${'aa' * 32}${'bb' * 32}1b',
      );

      final sig = await signer.signTypedData({'domain': {}, 'types': {}, 'message': {}});

      expect(sig, isA<EIP712Signature>());
      expect(sig.v, 27);
    });
  });

  group('PrivySigner.signDigest', () {
    test('throws UnsupportedError', () {
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => '',
      );

      expect(
        () => signer.signDigest(Uint8List(32)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('PrivySigner — signature parsing', () {
    PrivySigner signerWith(String sigHex) {
      return PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => sigHex,
      );
    }

    test('parses valid 65-byte 0x-prefixed signature', () async {
      final sig = await signerWith('0x${'aa' * 32}${'bb' * 32}1b')
          .signTypedData({'domain': {}, 'types': {}, 'message': {}});
      expect(sig.v, 27);
      expect(sig.r, startsWith('0x'));
      expect(sig.s, startsWith('0x'));
    });

    test('accepts signature without 0x prefix', () async {
      final sig = await signerWith('${'aa' * 32}${'bb' * 32}1c')
          .signTypedData({'domain': {}, 'types': {}, 'message': {}});
      expect(sig.v, 28);
    });

    test('throws FormatException for wrong-length signature', () {
      final signer = signerWith('0xdeadbeef');
      expect(
        signer.signTypedData({'domain': {}, 'types': {}, 'message': {}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty signature', () {
      final signer = signerWith('');
      expect(
        signer.signTypedData({'domain': {}, 'types': {}, 'message': {}}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PrivySigner — error handling', () {
    test('throws PrivySigningException when rpcCaller throws it', () {
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async =>
            throw const PrivySigningException('user rejected'),
      );

      expect(
        signer.signTypedData({'domain': {}, 'types': {}, 'message': {}}),
        throwsA(isA<PrivySigningException>()),
      );
    });

    test('PrivySigningException.toString includes message', () {
      const ex = PrivySigningException('something went wrong');
      expect(ex.toString(), contains('something went wrong'));
      expect(ex.toString(), contains('PrivySigningException'));
    });
  });

  group('PrivySigner.fromWallet (factory)', () {
    // NOTE: We cannot test the real Privy SDK in unit tests.
    // The factory is tested indirectly via the constructor + rpcCaller injection.
    // Integration testing with the real SDK is a manual/E2E concern.
    test('factory exists as a static method', () {
      // Verify the static method is accessible (compile-time check).
      // Actual invocation requires a real EmbeddedEthereumWallet.
      expect(PrivySigner.fromWallet, isA<Function>());
    });

    test('rpcCall forwards requests to the underlying rpcCaller', () async {
      String? capturedMethod;
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, _) async {
          capturedMethod = method;
          return '0xabc';
        },
      );

      final result = await signer.rpcCall('eth_test', []);
      expect(capturedMethod, 'eth_test');
      expect(result, '0xabc');
    });
  });

  group('PrivySigner — E2E sign + verify via library', () {
    test('sign with PrivySigner and verify round-trips', () async {
      // Use LocalKeySigner to produce the "real" signature that a wallet would return.
      final localSigner = LocalKeySigner(privateKeyHex: _testPrivateKey);

      // Build a mock PrivySigner that delegates to LocalKeySigner's signTypedData.
      final privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async {
          // Parse the typed data JSON that PrivySigner sends to Privy.
          // PrivySigner remaps primaryType → primary_type for the Privy SDK.
          // LocalKeySigner uses on_chain which expects the EIP-712 camelCase key,
          // so we remap it back here (as the real Privy SDK would handle it natively).
          final typedData = jsonDecode(params[1] as String) as Map<String, dynamic>;
          if (typedData.containsKey('primary_type')) {
            typedData['primaryType'] = typedData.remove('primary_type');
          }
          final sig = await localSigner.signTypedData(typedData);
          // Reconstruct 65-byte hex: r(32) + s(32) + v(1)
          final rHex = sig.r.substring(2); // strip 0x
          final sHex = sig.s.substring(2);
          final vHex = sig.v.toRadixString(16).padLeft(2, '0');
          return '0x$rHex$sHex$vHex';
        },
      );

      final lpPayload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      final userData = AppSchema.buildUserData(
        memo: 'E2E test',
        eventTimestamp: BigInt.from(1700000000),
      );

      final chainId = 11155111; // Sepolia
      final easAddress = ChainConfig.forChainId(chainId)!.eas;

      final offchainSigner = OffchainSigner(
        signer: privySigner,
        chainId: chainId,
        easContractAddress: easAddress,
      );

      final signed = await offchainSigner.signOffchainAttestation(
        schema: AppSchema.definition,
        lpPayload: lpPayload,
        userData: userData,
      );

      expect(signed.signer.toLowerCase(), _testAddress.toLowerCase());
      expect(signed.uid, isNotEmpty);
      expect(signed.signature.v, anyOf(27, 28));

      // Verify
      final result = offchainSigner.verifyOffchainAttestation(signed);
      expect(result.isValid, isTrue);
      expect(result.recoveredAddress.toLowerCase(), _testAddress.toLowerCase());
    });
  });
}

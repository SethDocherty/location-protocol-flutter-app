import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/external_wallet_signer.dart';

const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('ExternalWalletSigner — interface contract', () {
    test('extends Signer', () {
      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}'),
      );
      expect(signer, isA<Signer>());
    });

    test('returns the address supplied at construction', () {
      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}'),
      );
      expect(signer.address, _testAddress);
    });
  });

  group('ExternalWalletSigner.signTypedData', () {
    test('invokes onSignTypedData callback with typed data', () async {
      Map<String, dynamic>? capturedData;

      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (typedData) async {
          capturedData = typedData;
          return EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}');
        },
      );

      final input = {'domain': {'name': 'Test'}, 'types': {}, 'message': {}};
      await signer.signTypedData(input);

      expect(capturedData, isNotNull);
      expect(capturedData!['domain']['name'], 'Test');
    });

    test('returns the EIP712Signature from the callback', () async {
      final expected = EIP712Signature(v: 28, r: '0x${'cc' * 32}', s: '0x${'dd' * 32}');

      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => expected,
      );

      final result = await signer.signTypedData({});
      expect(result.v, 28);
    });
  });

  group('ExternalWalletSigner.signDigest', () {
    test('throws UnsupportedError', () {
      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}'),
      );

      expect(
        () => signer.signDigest(Uint8List(32)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

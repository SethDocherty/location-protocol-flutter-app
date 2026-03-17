import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

import 'package:location_protocol_flutter_app/src/builder/attestation_builder.dart';
import 'package:location_protocol_flutter_app/src/eas/local_key_signer.dart';
import 'package:location_protocol_flutter_app/src/models/location_attestation.dart';
import 'package:location_protocol_flutter_app/src/services/legacy_location_protocol_service.dart';
import 'package:location_protocol_flutter_app/src/services/library_location_protocol_service.dart';
import 'package:location_protocol_flutter_app/src/services/location_protocol_config.dart';
import 'package:location_protocol_flutter_app/src/services/location_protocol_service.dart';

/// Well-known Hardhat test account #0.
const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  late EthPrivateKey privateKey;
  late LocalKeySigner signer;

  setUp(() {
    privateKey = EthPrivateKey.fromHex(_testPrivateKey);
    signer = LocalKeySigner(privateKey);
  });

  // ---------------------------------------------------------------------------
  // LegacyLocationProtocolService
  // ---------------------------------------------------------------------------

  group('LegacyLocationProtocolService', () {
    late LocationProtocolService service;

    setUp(() {
      service = const LegacyLocationProtocolService();
    });

    test('implements LocationProtocolService', () {
      expect(service, isA<LocationProtocolService>());
    });

    test('signAttestation returns a signed attestation', () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Legacy service test',
        eventTimestamp: 1700000000,
      );

      final signed = await service.signAttestation(
        attestation: unsigned,
        signer: signer,
      );

      expect(signed.signer, _testAddress);
      expect(signed.uid, isNotEmpty);
      expect(signed.signature, isNotEmpty);
    });

    test('recoverSigner returns the correct address after signing', () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        eventTimestamp: 1700000000,
      );

      final signed = await service.signAttestation(
        attestation: unsigned,
        signer: signer,
      );

      final recovered = service.recoverSigner(attestation: signed);
      expect(recovered, isNotNull);
      expect(recovered!.toLowerCase(), _testAddress.toLowerCase());
    });

    test('verifyAttestation returns true for a valid attestation', () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 51.5074,
        longitude: -0.1278,
        eventTimestamp: 1700000001,
      );

      final signed = await service.signAttestation(
        attestation: unsigned,
        signer: signer,
      );

      expect(service.verifyAttestation(attestation: signed), isTrue);
    });

    test('recoverSigner returns null for a tampered attestation', () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
        eventTimestamp: 1700000002,
      );

      final signed = await service.signAttestation(
        attestation: unsigned,
        signer: signer,
      );

      // Tamper: replace signer with a different address and verify fails.
      final tampered = OffchainLocationAttestation(
        eventTimestamp: signed.eventTimestamp,
        srs: signed.srs,
        locationType: signed.locationType,
        location: signed.location,
        recipeType: signed.recipeType,
        recipePayload: signed.recipePayload,
        mediaType: signed.mediaType,
        mediaData: signed.mediaData,
        memo: signed.memo,
        recipient: signed.recipient,
        expirationTime: signed.expirationTime,
        revocable: signed.revocable,
        uid: signed.uid,
        signature: signed.signature,
        signer: '0x0000000000000000000000000000000000000001',
        version: signed.version,
      );
      expect(service.verifyAttestation(attestation: tampered), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // LibraryLocationProtocolService (delegates to legacy — no behaviour change)
  // ---------------------------------------------------------------------------

  group('LibraryLocationProtocolService', () {
    late LocationProtocolService service;

    setUp(() {
      service = LibraryLocationProtocolService();
    });

    test('implements LocationProtocolService', () {
      expect(service, isA<LocationProtocolService>());
    });

    test('produces the same result as the legacy service', () async {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Library service parity test',
        eventTimestamp: 1700000000,
      );

      final legacy = const LegacyLocationProtocolService();
      final legacySigned = await legacy.signAttestation(
        attestation: unsigned,
        signer: signer,
      );
      final librarySigned = await service.signAttestation(
        attestation: unsigned,
        signer: signer,
      );

      // Both implementations should produce an attestation from the same signer.
      expect(librarySigned.signer, legacySigned.signer);
      expect(service.verifyAttestation(attestation: librarySigned), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // LocationProtocolConfig
  // ---------------------------------------------------------------------------

  group('LocationProtocolConfig', () {
    test('defaults to useLocationProtocolLibrary = false', () {
      const config = LocationProtocolConfig();
      expect(config.useLocationProtocolLibrary, isFalse);
    });

    test('can be set to true', () {
      const config = LocationProtocolConfig(useLocationProtocolLibrary: true);
      expect(config.useLocationProtocolLibrary, isTrue);
    });
  });
}

// ignore_for_file: constant_identifier_names

/// Deterministic golden-value fixtures for the Location Protocol EIP-712
/// signing and verification pipeline.
///
/// All values in this file were computed from the reference implementation
/// (ethers.js v6 + Dart `web3dart`) using the well-known Hardhat test
/// account #0 as the signer.  They serve as a locked behavioral baseline:
/// any change to encoding, hashing, or signing logic that alters these
/// values is a **protocol-breaking regression**.
///
/// The canonical test attestation:
/// ```
///   eventTimestamp : 1700000000
///   srs            : 'EPSG:4326'
///   locationType   : 'geojson-point'
///   location       : '{"type":"Point","coordinates":[-122.4194,37.7749]}'
///   recipeType     : []
///   recipePayload  : []
///   mediaType      : []
///   mediaData      : []
///   memo           : 'Test fixture'
///   recipient      : (none)
///   expirationTime : 0
///   revocable      : true
/// ```
library signing_fixtures;

// ---------------------------------------------------------------------------
// Signer
// ---------------------------------------------------------------------------

/// Well-known Hardhat test account #0 private key.
const kFixturePrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

/// EIP-55 checksummed address for [kFixturePrivateKey].
const kFixtureSignerAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

// ---------------------------------------------------------------------------
// Canonical attestation inputs
// ---------------------------------------------------------------------------

const kFixtureEventTimestamp = 1700000000;
const kFixtureSrs = 'EPSG:4326';
const kFixtureLocationType = 'geojson-point';

/// GeoJSON Point produced by [AttestationBuilder.fromCoordinates] for
/// lat=37.7749, lng=-122.4194.
const kFixtureLocation =
    '{"type":"Point","coordinates":[-122.4194,37.7749]}';

const kFixtureMemo = 'Test fixture';

// ---------------------------------------------------------------------------
// Golden intermediate outputs
// ---------------------------------------------------------------------------

/// keccak256 of the ABI-encoded attestation data (the nine schema fields).
///
/// This is the value used as the `data` hash inside the EIP-712 struct hash.
const kFixtureEncodedDataHash =
    '0x5abe8150636fe4ff75eed790c6346326e021ab42e3778830cba5236c6efec9ed';

/// EIP-712 domain separator for the Sepolia EAS deployment.
///
/// ```
/// keccak256(abi.encode(
///   typeHash,
///   keccak256("EAS Attestation"),
///   keccak256("0.26"),
///   11155111,
///   0xC2679fBD37d54388Ce493F1DB75320D236e1815e
/// ))
/// ```
const kFixtureDomainSeparator =
    '0xb0d90c6a70c303bb1c0f0c525fce9473dd6de970950af010b0f48ecff37baf73';

/// EIP-712 struct hash of the canonical `Attest` message.
const kFixtureStructHash =
    '0x5fb9c3ad70fff4b5d54490abd9dc3c32f3ebf0701107a5aaa650bba3f6ab668b';

/// Final EIP-712 signable digest: keccak256(0x1901 || domainSeparator || structHash).
const kFixtureDigest =
    '0xbfd229f387549f153d121f120991a21acff286d9e64d0990e4fc1ff2c9554223';

// ---------------------------------------------------------------------------
// Expected signed envelope shape
// ---------------------------------------------------------------------------

/// Signature `r` component (32 bytes, 0x-prefixed).
const kFixtureSigR =
    '0x374edce90bb71d7140256ef7ed9d7e6e1455be153f5a34c73fc78234ac35ad3d';

/// Signature `s` component (32 bytes, 0x-prefixed).
const kFixtureSigS =
    '0x630f5202046cae1a16fd618a824276ea079b925974735e200f4accc6e4a77976';

/// Signature `v` component (normalised to 27/28 Ethereum convention).
const kFixtureSigV = 27;

/// JSON-encoded signature string as stored in [OffchainLocationAttestation.signature].
const kFixtureSignatureJson =
    '{"v":27,"r":"0x374edce90bb71d7140256ef7ed9d7e6e1455be153f5a34c73fc78234ac35ad3d",'
    '"s":"0x630f5202046cae1a16fd618a824276ea079b925974735e200f4accc6e4a77976"}';

/// EAS offchain UID for the canonical test attestation.
const kFixtureUid =
    '0x53fadbbbce24eb4f38dff866ebdd63610ac5cf242b85898abdd73bbc3a9b2755';

/// Schema version tag embedded in every signed attestation.
const kFixtureAttestationVersion = 'astral-core-v0.1.0';

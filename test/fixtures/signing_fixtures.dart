// ignore_for_file: constant_identifier_names

library signing_fixtures;

// ---------------------------------------------------------------------------
// Signer
// ---------------------------------------------------------------------------

const kFixturePrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const kFixtureSignerAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

// ---------------------------------------------------------------------------
// Canonical attestation inputs
// ---------------------------------------------------------------------------

const kFixtureLpVersion    = '1.0.0';
const kFixtureEventTimestamp = 1700000000;
const kFixtureSrs          = 'EPSG:4326';
const kFixtureLocationType = 'geojson-point';
const kFixtureLocation     =
    '{"type":"Point","coordinates":[-122.4194,37.7749]}';
const kFixtureMemo         = 'Test fixture';

// ---------------------------------------------------------------------------
// Golden intermediate outputs  (LP-compliant schema)
// ---------------------------------------------------------------------------

/// keccak256 of the ABI-encoded attestation data (LP-compliant schema, 10 fields).
const kFixtureEncodedDataHash =
    '0xfd87928229c64ec3be30d802d4afcab546e9a70dfd377552e7546ca56cc7e2a7';

/// EIP-712 domain separator for the Sepolia EAS deployment (unchanged).
const kFixtureDomainSeparator =
    '0xb0d90c6a70c303bb1c0f0c525fce9473dd6de970950af010b0f48ecff37baf73';

/// EIP-712 struct hash of the canonical Attest message.
const kFixtureStructHash =
    '0x923cf6d468732265290da677929d2ea717a2b868b4d79c843ca6e8314779819c';

/// Final EIP-712 signable digest.
const kFixtureDigest =
    '0xd898134a21e0ff911e4416ce1cca7acc0f197d7b904cfb35df07b0e50d5480ed';

// ---------------------------------------------------------------------------
// Expected signed envelope
// ---------------------------------------------------------------------------

const kFixtureSigR =
    '0x5b2bc06694d56936e20f8c897e2027331d5365b9acea9c6d108e084b2b978b3b';
const kFixtureSigS =
    '0x0511cadaba5db554a188f287c0a89cb31a563548de226b1d021b21fc5d33710f';
const kFixtureSigV = 27;

const kFixtureSignatureJson =
    '{"v":27,"r":"0x5b2bc06694d56936e20f8c897e2027331d5365b9acea9c6d108e084b2b978b3b",'
    '"s":"0x0511cadaba5db554a188f287c0a89cb31a563548de226b1d021b21fc5d33710f"}';

const kFixtureUid =
    '0x0918017e047741e823b04bfc5a31e3f09c59085e84461ffc1622808fbe0b6dce';

const kFixtureAttestationVersion = 'astral-core-v0.1.0';

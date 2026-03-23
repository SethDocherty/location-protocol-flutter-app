const { ethers } = require('ethers');
const message = `localhost wants you to sign in with your Ethereum account:
0x3074c8732366ce5db80986aba8fb69897872ddb9

By signing, you are proving you own this wallet and logging in. This does not initiate a transaction or cost any fees.

URI: https://localhost
Version: 1
Chain ID: 11155111
Nonce: 1adf8f03b87964246a25a2b8175808d724901977f33b41f6eabfba4f287aa5d9
Issued At: 2026-03-21T05:10:10.749260Z
Resources:
- https://privy.io`;

const sig = '0x09ddfd50408099e46f642edb056fd28e58147c26c1734d1bd15c73b2f6505e6f3099143ac7677e9b4bf4e39193dbae580fa9ef2a3adc5853363a24257f9904031b';

const recovered = ethers.verifyMessage(message, sig);
console.log('Recovered:', recovered.toLowerCase());
console.log('Expected: ', '0x3074c8732366ce5db80986aba8fb69897872ddb9');

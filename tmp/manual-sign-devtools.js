// 1. Connect MetaMask (will open the approval popup if not already connected)
await ethereum.request({ method: 'eth_requestAccounts' });

// 2. Sign
const msg = `localhost wants you to sign in with your Ethereum account:
0x3074C8732366cE5DB80986aBA8FB69897872DdB9

By signing, you are proving you own this wallet and logging in. This does not initiate a transaction or cost any fees.

URI: https://localhost
Version: 1
Chain ID: 1
Nonce: a4a27e712ed1f07c65a86297b81735e8f87a3e8d00c28c91ecbc8ad39da73ab0
Issued At: 2026-03-16T06:06:27.065197Z
Resources:
- https://privy.io`;

const hex = '0x' + Array.from(new TextEncoder().encode(msg))
  .map(b => b.toString(16).padStart(2, '0')).join('');

const sig = await ethereum.request({
  method: 'personal_sign',
  params: [hex, '0x3074C8732366cE5DB80986aBA8FB69897872DdB9']
});

console.log(sig);
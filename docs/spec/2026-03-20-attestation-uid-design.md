# Onchain Attestation UID Retrieval Design

## Overview
Currently, the App only yields a Transaction Hash (`txHash`) upon creating an onchain attestation. This design details how we will wait for the transaction to be mined, extract the corresponding Attestation UID from the EVM event logs, and display dynamic explorer links pointing to Etherscan and EAS Scan.

## Architecture & Responsibilities

### 1. `AttestationService`
We will add a new helper method: `Future<String> waitForAttestationUid(String txHash, {int maxRetries = 15, Duration pollInterval = const Duration(seconds: 2)})`.

**Responsibilities:**
- Poll `getTransactionReceipt(txHash)` until the receipt is returned.
- Upon decoding the receipt, iterate through the `logs` array.
- Locate the EAS `Attested` log by matching:
  - `log['address'].toLowerCase() == easAddress.toLowerCase()`
  - The Event Signature (topic[0]) for `Attested(address,address,bytes32,bytes32)`.
- Extract and return the `uid` from the log's non-indexed `data` field.

### 2. `OnchainAttestScreen`
This screen will be updated to remain thin. Upon calling `eth_sendTransaction`, it will:
- Set `_txHash = txHash`.
- Set `_submitting = true`.
- Await `AttestationService.waitForAttestationUid(txHash)`.
- Save `_uid = uid` and `_submitting = false`.

**UI Considerations:**
- Show a "Transaction Submitted" partial success state while waiting for the receipt.
- Once mined, show the Attestation UID underneath the TX Hash.
- Update the bottom action buttons to include dynamically generated "View on Block Explorer" and "View on EAS Scan" links based on `service.chainId`.

## Rationale
By encapsulating the polling and log parsing into `AttestationService`, we protect our UI layer from brittleness. If the structure of EVM logs changes or if we alter our RPC mechanisms, the `OnchainAttestScreen` will not need to be refactored.


## Additional support

Links to supporting easscan and the onchain transaction explorer sites:

| Network | EASScan | Explorer |
|---------|---------|-----------|
| Ethereum | https://easscan.org/ | https://etherscan.io/ |
| Optimism | https://optimism.easscan.org | https://optimistic.etherscan.io/ |
| Base | https://base.easscan.org | https://basescan.org/ |
| Ink | https://ink.easscan.org/ | https://explorer.inkonchain.com/ |
| Arbitrum | https://arbitrum.easscan.org/ | https://arbiscan.io/ |
| Arbitrum Nova | https://arbitrum-nova.easscan.org/ | https://nova.arbiscan.io/ |
| Polygon | https://polygon.easscan.org/ | https://polygonscan.com/ |
| Scroll | https://scroll.easscan.org/ | https://scrollscan.com/ |
| Linea | https://linea.easscan.org/ | https://lineascan.build/ |
| Celo | https://celo.easscan.org/ | https://celoscan.io/ |
| Sepolia | https://sepolia.easscan.org/ | https://sepolia.etherscan.io/ |
| Optimism Sepolia | https://optimism-sepolia.easscan.org/ | https://sepolia-optimism.etherscan.io/ |
| Arbitrum Sepolia | https://arbitrum-sepolia.easscan.org/ | https://sepolia.arbiscan.io/ |
| Base Sepolia | https://base-sepolia.easscan.org/ | https://sepolia.basescan.org/ |
| Polygon Amoy | https://polygon-amoy.easscan.org/ | https://amoy.polygonscan.com/ |
| Scroll Sepolia | https://scroll-sepolia.easscan.org/ | https://sepolia.scrollscan.com/ |
| Telos | https://telos.easscan.org/ | https://teloscan.io/ |
| Soneium | https://soneium.easscan.org/ | https://soneium.blockscout.com/ |
| Blast | Does not exist | https://blastexplorer.io/ |
| Ink Sepolia | Does not exist | https://explorer-sepolia.inkonchain.com/ |
| Unichain | Does not exist | https://unichain.blockscout.com/ |

- For any other chains that are not in the list, default to listing just the transaction hash
- It looks like the pattern to view a transaction is `<explorer link>/tx/<txHash>` for EASScan and `<easscan link>/attestation/view/<uid>`. 

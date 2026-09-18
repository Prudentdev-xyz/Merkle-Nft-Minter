# Merkle NFT Minter

An ERC-721 minter with a Merkle-tree-gated allowlist phase and a public sale phase, built entirely with Solidity and Foundry.

## Overview

This contract lets a project run a two-phase NFT sale:

- **Allowlist phase** — only wallets included in a pre-committed Merkle tree can mint, each capped at their own individual allowance.
- **Public phase** — anyone can mint, capped at a flat per-wallet limit.

Both phases require exact payment, respect a hard supply cap, and are protected against reentrancy, duplicate claims, and unauthorized access.

## Features

- Configurable Merkle root, price, total supply, phase, and per-wallet allowance
- Each Merkle leaf binds a wallet address to its maximum allowance — proofs can't be reused with an altered amount
- Separate allowlist and public minting paths, each requiring exact payment
- Rejects invalid proofs, altered allowances, duplicate claims, over-minting, and mints attempted during an inactive phase
- Token metadata via a configurable base URI
- Owner-only pause/unpause and withdrawal controls
- Full event coverage for minting, phase changes, and admin actions

## Tech Stack

- **Solidity** `^0.8.20`
- **Foundry** (Forge, Cast) — build, test, and deploy
- **OpenZeppelin Contracts v5** — `ERC721`, `Ownable`, `Pausable`, `ReentrancyGuard`, `MerkleProof`

No TypeScript, Hardhat, or frontend tooling is used anywhere in this project — contract, tests, and deployment script are all Solidity, run through Foundry only.

## Project Structure

```
src/
  MerkleMinter.sol        — the ERC-721 minter contract
test/
  MerkleMInter.t.sol       — Foundry test suite
script/
  MerkleMinter.s.sol       — Foundry deployment script
```

## Setup

1. **Install Foundry** (if not already installed):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone the repo and install dependencies:**
   ```bash
   git clone <your-repo-url>
   cd Merkle-Nft-Minter
   forge install OpenZeppelin/openzeppelin-contracts
   ```

3. **Create a `.env` file** in the project root (never commit this file):
   ```dotenv
   PRIVATE_KEY=0xyour_private_key_here
   SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   ```

   Make sure `.env` is listed in `.gitignore` before doing anything else.

4. **Confirm the remapping** exists in `foundry.toml`:
   ```toml
   remappings = [
       "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
   ]
   ```

## Building

```bash
forge build
```

## Testing

```bash
forge test -vv
```

The test suite covers:
- The main allowlist mint flow with a valid proof
- Rejection of an invalid proof
- Rejection of mints attempted during the inactive phase
- Rejection of a wallet exceeding its allowlist allowance (duplicate claim)
- Supply exhaustion, isolated using a separate small-supply contract instance
- Exact-payment enforcement, including a fuzz test across many incorrect payment amounts
- The public mint flow and its per-wallet limit
- Phase transitions across all three states

## Deployment

Load your environment variables into the shell first:
```bash
set -a
source .env
set +a
```

**Simulate locally (no real transaction):**
```bash
forge script script/MerkleMinter.s.sol
```

**Deploy to Sepolia:**
```bash
forge script script/MerkleMinter.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

**Deploy and verify source code in one step:**
```bash
forge script script/MerkleMinter.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

Before deploying for real, open `script/MerkleMinter.s.sol` and replace the placeholder `merkleRoot_` and `baseURI_` values with your actual allowlist root and metadata location.

## Contract Architecture

### Phases
```
Inactive → Allowlist → Public
```
Controlled by the owner via `setPhase()`. Defaults to `Inactive` at deployment.

### Allowlist minting (`mintAllowlist`)
Each wallet's allowance is committed inside a Merkle leaf as `keccak256(bytes.concat(keccak256(abi.encode(wallet, allowance))))`. On mint, the caller submits their claimed allowance alongside a Merkle proof; the contract reconstructs the leaf and verifies it against the stored root before allowing the mint.

### Public minting (`mintPublic`)
No proof required — gated only by the active phase and a flat `publicMaxPerWallet` cap.

### Admin controls
`setMerkleRoot`, `setPrice`, `setPhase`, `pause`/`unpause`, `setBaseURI`, and `withdraw` are all owner-only.

## Building the Merkle Tree

The allowlist root is generated off-chain, entirely in Solidity (no JS/TS tooling), using [Murky](https://github.com/dmfxyz/murky):

```bash
forge install dmfxyz/murky
```

Leaves must be constructed with the exact same encoding used in the contract — `keccak256(bytes.concat(keccak256(abi.encode(wallet, allowance))))` — or on-chain verification will never match the off-chain tree.

## License

MIT
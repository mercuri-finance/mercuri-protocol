<p align="center">
  <img src="https://www.mercuri.finance/logo.svg" alt="Mercuri Protocol Logo" width="180" />
</p>

# Mercuri Protocol Contracts

<p align="left">
  <img src="https://img.shields.io/badge/version-v1.0.0-blue.svg" alt="Version v1.0.0" />
</p>

This repository contains the core smart contracts for the **Mercuri protocol**.

Mercuri provides non-custodial vaults for managing Uniswap V3 liquidity positions with optional delegated automation.

---

## Architecture Overview

The protocol is composed of:

- **VaultFactory**
  Deploys vaults, enforces one-vault-per-owner-per-pool, and defines global protocol fees.

- **Vault**
  A non-custodial smart vault managing a single Uniswap V3 LP position.

- **ManagerRegistry**
  An advisory registry of protocol-approved automation managers.

- **Shared libraries and interfaces**
  Fee configuration, ERC20 helpers, and Uniswap interfaces.

---

## Trust Model

Mercuri follows a **vault-owner-centric trust model**:

- Vaults are **non-custodial**
- Vault owners retain full control of funds
- Protocol fees are applied transparently via the factory
- Automation managers are **delegated, not privileged**

### Manager Design

- Each vault is deployed with an **initial manager address**, assigned by the protocol and registry-approved at deployment time
- **Only the vault owner may change the manager**
- The `ManagerRegistry` is **advisory only**
- Manager approval is **not enforced after deployment**

> Vault owners may override the manager at their own risk.
> A malicious manager can only affect **that specific vault**, never the wider protocol.

---

## Scope

### Included

- Core protocol contracts
- Vault and factory logic
- Manager delegation mechanisms
- Interfaces and shared libraries

### Excluded

- Frontend code
- Bots or off-chain services
- Keeper infrastructure
- UI integrations

---

## Development

This project uses **Hardhat**.

### Install dependencies

```bash
npm install
```

### Compile contracts

```bash
npx hardhat compile
```

### Run tests

```bash
npx hardhat test
```

All tests must pass before submitting changes.

---

## Security Model

### Vault Ownership

Each Mercuri Vault has a single immutable owner. The owner:

- Controls capital withdrawals
- May delegate operational authority to a manager
- Bears full responsibility for manager selection

### Manager Delegation

Vault owners may assign a `manager` address with limited permissions:

Managers MAY:

- Rebalance positions
- Collect fees
- Adjust liquidity parameters

Managers MAY NOT:

- Withdraw funds
- Transfer assets out of the vault
- Change ownership or protocol configuration

The protocol does not enforce manager approvals after deployment.
ManagerRegistry is advisory only.

### Trust Assumptions

- Vault owners are responsible for selecting trusted managers
- Assigning a malicious manager may result in poor strategy execution
- Capital theft is prevented by contract-level access control

This tradeoff is intentional and documented.

## Security Notes

- Vaults are **immutable** once deployed
- Reentrancy protection is enforced
- Protocol fees are bounded by factory configuration
- Managers cannot withdraw funds to arbitrary addresses
- ETH is accepted only from trusted sources (WETH unwraps or swap router)

If you discover a vulnerability, **do not open a public issue**.

Instead, report it privately to:

**[info@mercuri.finance](mailto:info@mercuri.finance)**

---

## License

All contracts in this repository are licensed under **MIT**, unless otherwise noted.

---

## Status

This repository is under active development.
Interfaces and behavior are stable unless explicitly marked otherwise.

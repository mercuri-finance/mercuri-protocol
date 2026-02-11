# Mercuri Protocol — Audit Response & Remediation Report

**Audit Source:** CredShields Smart Contract Security Audit
**Audit Window:** Jan 30 – Feb 1, 2026
**Retest:** Feb 10, 2026
**Final Report:** Feb 11, 2026
**Scope:** Mercuri Protocol Contracts (Vault, VaultFactory, ManagerRegistry, supporting interfaces)

This document provides a complete, item-by-item response to all findings reported by CredShields.

All identified vulnerabilities have been remediated and confirmed during the retesting phase.

---

# Executive Summary

During the assessment, CredShields identified **14 total findings**:

- **Critical:** 3
- **Medium:** 1
- **Low:** 5
- **Informational:** 4
- **Gas:** 1

All issues were fixed prior to the final retest and verified by the auditors.

---

# Critical Findings

## C001 — Performance Fee Bypass via Collect Ordering

**Status:** Fixed

**Root Cause:**
Authorized manager/owner could call `collect()` after removing liquidity and before protocol fees were applied, bypassing performance fees.

**Remediation:**

- Removed vulnerable public execution path.
- Restricted fee collection to fee-safe lifecycle flows.
- Enforced protocol fee application ordering before principal withdrawal.

---

## C002 — Performance Fees Applied to Principal

**Status:** Fixed

**Root Cause:**
Fee calculation used full token balances, mixing swap fees with principal.

**Remediation:**

- Introduced accounting separation between:
    - Swap fees
    - Principal
    - Idle balances

- Fees now applied strictly to earned swap fees only.

---

## C003 — Unrestricted Liquidity Decrease Breaks Fee Accounting

**Status:** Fixed

**Root Cause:**
Liquidity could be decreased outside enforced lifecycle, causing:

- Fee bypass (full removal case)
- Fees charged on principal (partial removal case)

**Remediation:**

- Enforced strict lifecycle ordering:
    1. Collect swap fees
    2. Apply protocol fee
    3. Decrease liquidity

---

# Medium Severity Findings

## M001 — Withdrawals Can Revert for Non-Payable Owner

**Status:** Fixed

**Root Cause:**
Vault always unwrapped WETH → ETH, assuming owner can receive ETH.

**Remediation:**

- Added configurable withdrawal behavior:
    - Transfer WETH directly, or
    - Unwrap to ETH

---

# Low Severity Findings

## L001 — Router Can Force WETH Conversion

**Status:** Fixed

**Remediation:**

- ETH accepted only when WETH is part of the pool.

---

## L002 — Unapproved Manager Assignable at Deployment

**Status:** Fixed

**Remediation:**

- Factory now validates manager against ManagerRegistry.

---

## L003 — ManagerRegistry Owner Irrecoverable

**Status:** Fixed

**Remediation:**

- Ownership transfer capability introduced.

---

## L004 — Swap Fee Upper Bound Not Enforced

**Status:** Fixed

**Remediation:**

- Enforced BPS ceiling (≤ 10,000).

---

## L005 — Floating / Outdated Solidity Pragma

**Status:** Fixed

**Remediation:**

- Locked compiler version across all contracts.

---

# Informational Findings

## I001 — Mint Allowed Zero Slippage Protection

**Status:** Fixed

**Remediation:**

- Enforced non-zero `amount0Min` / `amount1Min`.

---

## I002 — Misspelled Event Name

**Status:** Fixed

**Remediation:**

- Corrected event name for monitoring compatibility.

---

## I003 — Missing Zero Address Validations

**Status:** Fixed

**Remediation:**

- Added validation across all address setters.

---

## I004 — Ownable2Step Recommended

**Status:** Fixed

**Remediation:**

- Migrated ownership model to safer transfer pattern.

---

# Gas Optimization

## G001 — Conditional Operator Optimization

**Status:** Fixed

**Remediation:**

- Replaced `x > 0` with `x != 0` where applicable.

---

# Final Security Statement

- All 14 findings identified by CredShields were fixed.
- All fixes were verified in retest.
- No outstanding security vulnerabilities remain in the audited scope.
- Critical business logic vulnerabilities related to fee accounting and lifecycle ordering have been fully resolved.

This report reflects the current secured state of the Mercuri Protocol following the February 2026 audit.

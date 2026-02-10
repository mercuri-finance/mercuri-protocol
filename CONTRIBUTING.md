# Contributing to Mercuri Protocol Contracts

Thank you for your interest in contributing to the Mercuri protocol.

This repository contains security-sensitive smart contracts.
Contributions are welcome, but must follow the guidelines below to ensure
correctness, safety, and long-term maintainability.

---

## Scope of Contributions

We welcome contributions related to:

- Bug fixes and improvements to existing contracts
- Tests and test coverage improvements
- Documentation clarifications
- Gas optimizations (with benchmarks)
- Security improvements or hardening
- Refactoring that improves clarity without changing behavior

Out of scope:

- Frontend code
- Off-chain services or bots
- Major architectural changes without prior discussion
- Experimental or speculative features

---

## Before You Start

Before opening a pull request:

1. Review the existing documentation and contracts
2. Check for open issues or discussions related to your change
3. For non-trivial changes, open an issue first to discuss intent

Large or breaking changes should always be discussed before implementation.

---

## Development Setup

This project uses Hardhat.

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

All tests must pass before submitting a pull request.

---

## Coding Standards

### Solidity

- Solidity version is fixed in `hardhat.config.ts`
- Use explicit visibility (`public`, `external`, `internal`, `private`)
- Prefer immutability where possible
- Avoid unnecessary storage writes
- No unused variables or dead code
- Follow checks-effects-interactions pattern
- Use custom errors where appropriate

### Style

- Clear, descriptive naming
- Favor readability over cleverness
- Keep functions small and focused
- Comment why, not what, when logic is non-obvious

---

## Tests

- New functionality must include tests
- Bug fixes should include regression tests
- Tests should be deterministic and isolated
- Avoid reliance on block timestamps unless explicitly required

---

## Security Considerations

Mercuri contracts are security-critical.

Please be mindful of:

- Reentrancy
- Access control
- Integer overflows / underflows
- Precision loss
- External call safety
- Upgrade and permission boundaries

If you discover a security vulnerability, do not open a public issue.

Instead, report it privately to the Mercuri team via email: <info@mercuri.finance>

---

## Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes with clear commits
4. Ensure all tests pass
5. Open a pull request with:
    - A clear description of the change
    - Motivation and context
    - Any relevant trade-offs or risks

Pull requests may be reviewed for:

- Correctness
- Security
- Readability
- Scope appropriateness

The Mercuri team may request changes or decline contributions that do not
align with the project’s direction.

---

## License

By contributing, you agree that your contributions will be licensed under
the same license as this repository.

---

Thank you for helping improve Mercuri.

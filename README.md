---
title: "Learning Path"
description: "Post-Quantum PKI Lab - Hands-on learning for PQC migration"
---

# QLAB

**Post-Quantum PKI Lab**

QLAB is an educational resource to help teams understand PKI and Post-Quantum Cryptography (PQC) migration through hands-on practice.

> **"The PKI is the tool for transition — post-quantum is an engineering problem, not magic."**

**What you'll learn:**

- Understand the quantum threats to current cryptography (**SNDL**, **TNFL**)
- **Assess your PQC migration urgency** using Mosca's theorem
- Issue classical and post-quantum certificates with the **same workflow**
- Build complete PQC hierarchies (Root CA → Issuing CA → End-Entity)
- Deploy **hybrid certificates** for backward-compatible migration
- Manage full lifecycle: revocation, OCSP, CRL
- Sign code, timestamp documents, and create **LTV signatures**
- Encrypt with **ML-KEM** key encapsulation (the new pattern)
- Practice **crypto-agile** CA migration

QLAB uses **[Qpki](https://github.com/qpki/qpki)** for all PKI operations.

---

## Installation

**Prerequisites:**
- **Git** — for cloning the repository
- **Bash** — for running demos (Git Bash or WSL on Windows)
- **OpenSSL 3.x** — optional, for cross-verification commands

### macOS / Linux

```bash
git clone https://github.com/qpki/qlab.git
cd qlab
./tooling/install.sh
```

The install script downloads the latest [qpki](https://github.com/qpki/qpki) release to `/usr/local/bin`. Run it again to check for updates.

### Windows

```powershell
# 1. Install QPKI (PowerShell, run as Administrator)
git clone https://github.com/qpki/qlab.git
cd qlab
.\tooling\install.ps1

# 2. Run demos (requires Git Bash or WSL)
./journey/00-revelation/demo.sh
```

> **Note:** The install script works in PowerShell, but the demos require [Git Bash](https://git-scm.com/downloads) or [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

### Getting Started

```bash
./journey/00-revelation/demo.sh
```

---

## Learning Path

**Total time: ~2h** | **Quick path: 20 min** (Revelation + Quick Start)

### 🗺️ Journey Map

```
┌───────────────────────────────────────────────────────────────────────┐
│  AWARENESS              BUILD                    LIFECYCLE            │
│  ┌──────┐ ┌──────┐      ┌──────┐ ┌──────┐    ┌──────┐ ┌──────┐       │
│  │Lab-00│→│Lab-01│  →   │Lab-02│→│Lab-03│ →  │Lab-04│→│Lab-05│       │
│  │Why?  │ │How?  │      │Chain │ │Hybrid│    │CRL   │ │OCSP  │       │
│  └──────┘ └──────┘      └──────┘ └──────┘    └──────┘ └──────┘       │
│                                                       ↓              │
│  MIGRATION              ENCRYPTION           LONG-TERM SIGS          │
│  ┌──────┐               ┌──────┐            ┌──────┬──────┬──────┐   │
│  │Lab-10│  ←            │Lab-09│    ←       │Lab-06│Lab-07│Lab-08│   │
│  │Agile │               │KEM   │            │Sign  │Time  │LTV   │   │
│  └──────┘               └──────┘            └──────┴──────┴──────┘   │
└───────────────────────────────────────────────────────────────────────┘
```

---

### 🚀 Awareness

| # | Lab | Time | Takeaway |
|---|-----|------|----------|
| 0 | [**The Quantum Threat**](journey/00-revelation/) | 10 min | Your data is already being recorded |
| 1 | [**Classical vs Post-Quantum**](journey/01-quickstart/) | 10 min | Same workflow, just different algorithms |

↓ *Let's build!*

### 📚 Build

| # | Lab | Time | Takeaway |
|---|-----|------|----------|
| 2 | [**Full PQC Chain**](journey/02-full-chain/) | 10 min | Build a 100% PQC chain |
| 3 | [**Hybrid**](journey/03-hybrid/) | 10 min | Or hybrid to coexist with legacy |

↓ *PKI operations stay identical*

### ⚙️ Lifecycle

| # | Lab | Time | Takeaway |
|---|-----|------|----------|
| 4 | [**Revocation**](journey/04-revocation/) | 10 min | Revoke = same command |
| 5 | [**OCSP**](journey/05-ocsp/) | 10 min | Verify = same protocol |

↓ *Sign, timestamp, archive for decades*

### 💼 Long-Term Signatures

| # | Lab | Time | Takeaway |
|---|-----|------|----------|
| 6 | [**Code Signing**](journey/06-code-signing/) | 10 min | Signatures that outlive the threat |
| 7 | [**Timestamping**](journey/07-timestamping/) | 15 min | Prove WHEN, forever |
| 8 | [**LTV**](journey/08-ltv-signatures/) | 15 min | Bundle proofs for offline verification |

↓ *Except for encryption...*

### 🔐 Encryption

| # | Lab | Time | Takeaway |
|---|-----|------|----------|
| 9 | [**Encryption**](journey/09-cms-encryption/) | 15 min | KEM keys require a new pattern: attestation |

↓ *And for production migration?*

### 🧭 Migration

| # | Lab | Time | Takeaway |
|---|-----|------|----------|
| 10 | [**Crypto-Agility**](journey/10-crypto-agility/) | 15 min | CA versioning + trust bundles |

---

## Algorithms

### Post-Quantum (NIST 2024)
- **ML-DSA** (FIPS 204) — Lattice-based signatures → replaces ECDSA
- **SLH-DSA** (FIPS 205) — Hash-based signatures (conservative)
- **ML-KEM** (FIPS 203) — Key encapsulation → replaces ECDH

### Hybrid (Transition)
- Catalyst certificates (ITU-T X.509 9.8)
- Composite certificates *(supported, no lab demo)*

See [Qpki](https://github.com/qpki/qpki#supported-algorithms) for the full list of supported algorithms.

---

## Resources

- [Qpki](https://github.com/qpki/qpki) — The PKI toolkit used by QLAB
- [Glossary](docs/GLOSSARY.md) — PQC and PKI terminology
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Common issues and solutions
- [NIST Post-Quantum Cryptography](https://csrc.nist.gov/projects/post-quantum-cryptography)
- [FIPS 203 (ML-KEM)](https://csrc.nist.gov/pubs/fips/203/final)
- [FIPS 204 (ML-DSA)](https://csrc.nist.gov/pubs/fips/204/final)
- [ITU-T X.509 (Hybrid Certificates)](https://www.itu.int/rec/T-REC-X.509)

---

## License

Apache License 2.0 — See [LICENSE](https://github.com/qpki/qlab/blob/main/LICENSE)

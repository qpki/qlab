---
title: "Lab-00: The Quantum Threat"
description: "Understand the quantum threat with SNDL and TNFL attacks, Mosca's theorem for migration urgency, and NIST post-quantum algorithm standards."
---

# Lab-00: The Quantum Threat

## Why Change Algorithms?

> **Key Message:** Your data is already being recorded. The clock is ticking.

Classical PKI with ECDSA works. So why change?

A classical PKI is structurally correct — but cryptographically fragile in the long term.

Because **quantum computers will break everything**.

---

## The Scenario

*"Our sensitive data is encrypted. Why should I worry about quantum computers that don't exist yet?"*

## The Twin Threats

**Q-Day** is the day quantum computers become powerful enough to break current cryptography (RSA, ECC, ECDSA, ECDH). Estimates range from 10-15 years, but the exact date is unknown — and irrelevant for data that must stay secret for decades.

Quantum computers will break both **encryption** and **signatures**:

### SNDL: Store Now, Decrypt Later

Adversaries are **recording your encrypted traffic today**. When quantum computers arrive, they'll decrypt it all. This is called **Store Now, Decrypt Later (SNDL)** — also known as **Harvest Now, Decrypt Later (HNDL)**.

**The attack does not require breaking encryption today — only recording traffic.**

```
TODAY                           FUTURE (5-15 years?)
─────                           ────────────────────

  You                              Adversary
   │                                  │
   │ Encrypted data ──────────────►   │ Stored encrypted data
   │ (ECDH key exchange)              │
   │                                  │
   │                                  ▼
   │                              Quantum
   │                              Computer
   │                                  │
   │                                  ▼
   │                              Decrypted!
   │                              All your secrets
```

**The exposure window:**

```
TODAY            Q-DAY             +50 years
(2025)           (~2035)           (2075)
  │                │                 │
  ▼                ▼                 ▼
┌────────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│    CAPTURED     │              EXPOSED                         │
└────────────────────────────────────────────────────────────────┘
        │                │                 │
        │                │                 └─ Data should stay secret until here
        │                └─ Q-Day: Quantum decrypts everything
        └─ Adversaries recording NOW

░░░ Encrypted but captured (false sense of security)
▓▓▓ EXPOSED for 40 years (until required confidentiality ends)
```

**The harvest attack:**

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Adversary taps network traffic (undersea cables, ISPs...)   │
│  2. Captures everything: diplomatic exchanges, medical records, │
│     financial transactions, trade secrets                       │
│  3. Stores ALL encrypted data — cheap storage, patient waiting  │
│  4. Quantum computer arrives                                    │
│  5. Adversary decrypts entire archive at once                   │
│  6. Medical records, state secrets, financial data — exposed    │
└─────────────────────────────────────────────────────────────────┘

The attack requires NO action after quantum arrives.
Everything was already captured. Just decrypt and read.
```

→ **Solution:** ML-KEM (quantum-resistant key exchange)

### TNFL: Trust Now, Forge Later

Signatures you trust today can be **forged** once quantum computers arrive. This is called **Trust Now, Forge Later (TNFL)** — also known as **Sign Today, Forge Tomorrow (STFT)**. A forged signature is instant and undetectable — malicious firmware signed with a forged key installs without question.

**Forged signatures are indistinguishable from legitimate ones.**

```
TODAY                           FUTURE (5-15 years?)
─────                           ────────────────────

  Your PKI                         Attacker
   │                                  │
   │ Certificates signed ─────────►   │ Captured certificates
   │ with ECDSA                       │ and public keys
   │                                  │
   │                                  ▼
   │                              Quantum
   │                              Computer
   │                                  │
   │                                  ▼
   │                              Forged certificates!
   │                              Impersonation possible
```

**The forgery attack:**

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Attacker extracts your PUBLIC key (available in any cert)   │
│  2. Quantum computer derives your PRIVATE key                   │
│  3. Attacker signs malware with YOUR key                        │
│  4. Malware passes all signature verification ✓                 │
│  5. Systems auto-update with "trusted" malicious code           │
└─────────────────────────────────────────────────────────────────┘

Unlike SNDL, forgery is INSTANT once quantum arrives.
No need to capture anything beforehand — just your public key.
```

→ **Solution:** ML-DSA (quantum-resistant signatures)

---

## Who Should Worry?

| Data Type | Sensitivity Lifetime | SNDL Risk |
|-----------|---------------------|-----------|
| TLS session keys* | Minutes | Low |
| Personal health records | Decades | **Critical** |
| Government secrets | 25-50 years | **Critical** |
| Financial records | 7-10 years | High |
| Trade secrets | Variable | High |
| Military communications | 50+ years | **Critical** |

*\*But what about the content? User actions, exchanged data, and browsing patterns may remain sensitive long after the session ends.*

**If your data must remain secret for more than 10 years, you're already late.**

*Legal, medical, and industrial records outlive the cryptographic algorithms that protect them.*

---

## When to Act

| Data Sensitivity Lifetime | Action Required |
|--------------------------|-----------------|
| < 5 years | Monitor, plan migration |
| 5-10 years | Begin hybrid deployment |
| 10-25 years | Urgent: Deploy PQC now |
| > 25 years | Critical: Should already have PQC |

---

## Mosca's Theorem

Michele Mosca formalized the urgency of migration:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   If  X + Y > Z  →  ACT NOW                                     │
│                                                                 │
│   X = Security shelf-life (how long your data must stay secret) │
│   Y = Time to migrate your systems to post-quantum              │
│   Z = Time until quantum computers break current crypto         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**The intuition:** If the time your data needs protection (X) plus the time to migrate (Y) exceeds the time until quantum arrives (Z), you're already late.

### Example: Medical Records (HIPAA)

```
X = 50 years  (patient records must stay confidential)
Y = 5 years   (infrastructure migration time)
Z = 10 years  (quantum computer estimate)

X + Y = 55 years
Z = 10 years

55 > 10  →  ACT NOW

You need 55 years of protection, but quantum arrives in 10.
```

---

## Run the Demo

```bash
./journey/00-revelation/demo.sh
```

The demo is an **interactive Mosca calculator** that helps you assess your PQC migration urgency based on your data's sensitivity lifetime.

---

## The Solution: Post-Quantum Algorithms

NIST finalized 3 post-quantum algorithms (August 2024).

*You don't need to memorize these numbers. The important takeaway is the order of magnitude and the trade-off: larger keys and signatures in exchange for quantum resistance.*

| Algorithm | Standard | Family | Purpose | Replaces | Protects Against |
|-----------|----------|--------|---------|----------|------------------|
| ML-KEM | FIPS 203 | Module Lattice | Key exchange | ECDH, RSA-KEM | SNDL |
| ML-DSA | FIPS 204 | Module Lattice | Signatures | ECDSA, RSA | TNFL |
| SLH-DSA | FIPS 205 | Stateless Hash | Signatures (conservative) | — | TNFL |

### Classical vs Post-Quantum: At a Glance

*Before diving into variants, here's what changes:*

**Signatures (protects against TNFL)**

| | ECDSA P-384 | ML-DSA-65 | Change |
|--|-------------|-----------|--------|
| Public Key | 97 B | 1,952 B | 20x larger |
| Signature | 96 B | 3,309 B | 34x larger |
| Signing | 0.9 ms | 0.7 ms | **~20% faster** |
| Verification | 0.3 ms | 0.15 ms | **2x faster** |

**Key Exchange (protects against SNDL)**

| | X25519 | ML-KEM-768 | Change |
|--|--------|------------|--------|
| Public Key | 32 B | 1,184 B | 37x larger |
| Ciphertext | 32 B | 1,088 B | 34x larger |
| Speed | ~0.05 ms | ~0.1 ms | ~2x slower (still sub-ms) |

**Bottom line:** Larger sizes, but signing/verification is faster. The trade-off is worth it for quantum resistance.

*For detailed sizes, variants, and benchmarks, see [Algorithm Reference](../../docs/ALGORITHM-REFERENCE.md#performance-benchmarks).*

---

## Security Agency Recommendations

Major security agencies have published concrete migration timelines:

### EU Regulatory Timeline (NIS Cooperation Group)

The European Union has established a coordinated roadmap for PQC adoption:

| Deadline | Requirement |
|----------|-------------|
| **End of 2026** | Complete cryptographic inventory and risk assessment. Begin pilot projects. |
| **End of 2030** | Migrate all high-risk systems to PQC. |
| **End of 2035** | Achieve full PQC coverage across all use cases. |

**What This Means:**

1. **Now**: Map all cryptographic assets and identify long-term data
2. **2025-2026**: Run hybrid pilots, test compatibility
3. **2027-2030**: Prioritize migration of sensitive systems
4. **Post-2030**: Complete transition, phase out classical-only systems

> The timeline is aggressive but achievable. Starting your inventory today is the first step.

### [NSA CNSA 2.0](https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF) (USA) — Timeline

| Use Case | Deadline | Algorithms |
|----------|----------|------------|
| Software/firmware signing | 2025 | ML-DSA |
| Web servers, cloud services | 2025 | ML-KEM + ML-DSA |
| VPNs, network equipment | 2026 | ML-KEM |
| Legacy systems | 2030 | Full migration |
| National security systems | 2035 | Complete transition |

### [ANSSI](https://cyber.gouv.fr/publications/avis-de-lanssi-sur-la-migration-vers-la-cryptographie-post-quantique) (France)

- **Hybrid mandatory** for high-security systems (classical + PQC)
- ML-KEM and ML-DSA approved for use
- Transition planning required now

### [BSI](https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Informationen-und-Empfehlungen/Quantentechnologien-und-Post-Quanten-Kryptografie/quantentechnologien-und-post-quanten-kryptografie_node.html) (Germany)

- PQC readiness assessment required for critical infrastructure
- Hybrid approach recommended during transition
- Migration plans must be in place

**The message is unanimous:** Start now. The transition takes years, and the threat is real.

---

## What You Learned

1. **SNDL is real:** Adversaries record encrypted traffic today → ML-KEM protects
2. **TNFL is real:** Signatures trusted today can be forged tomorrow → ML-DSA protects
3. **Timing matters:** Your data's sensitivity lifetime determines urgency
4. **NIST standards are ready:** ML-KEM (FIPS 203) and ML-DSA (FIPS 204) are finalized

---

## References

- [FIPS 203: ML-KEM Standard](https://csrc.nist.gov/pubs/fips/203/final)
- [FIPS 204: ML-DSA Standard](https://csrc.nist.gov/pubs/fips/204/final)
- [FIPS 205: SLH-DSA Standard](https://csrc.nist.gov/pubs/fips/205/final)
- [Mosca's Theorem](https://globalriskinstitute.org/publication/quantum-threat-timeline/)
- [NSA CNSA 2.0](https://media.defense.gov/2022/Sep/07/2003071836/-1/-1/0/CSI_CNSA_2.0_FAQ_.PDF)
- [ANSSI PQC Position](https://cyber.gouv.fr/publications/avis-de-lanssi-sur-la-migration-vers-la-cryptographie-post-quantique)
- [NIS Cooperation Group PQC Roadmap](https://digital-strategy.ec.europa.eu/en/library/coordinated-implementation-roadmap-transition-post-quantum-cryptography)

---

← [Quick Start](../01-quickstart/) | [QLAB Home](../../README.md) | [Next: Full Chain →](../02-full-chain/)

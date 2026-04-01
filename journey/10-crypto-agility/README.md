---
title: "Lab-10: Crypto-Agility"
description: "Implement CA rotation and trust bundle migration to switch algorithms without downtime, enabling gradual client migration."
---

# Lab-10: Crypto-Agility

## CA Rotation and Trust Bundle Migration

> **Key Message:** Crypto-agility = your PKI can switch algorithms without downtime. This requires versioning, not just configuration.

---

## The Scenario

*"We have 10,000 ECDSA certificates in production. We need to migrate to ML-DSA. But we can't break everything at once."*

```
CURRENT SITUATION
─────────────────

  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │  Production                                                 │
  │  ──────────                                                 │
  │                                                             │
  │  ┌───────────┐  ┌───────────┐  ┌───────────┐              │
  │  │  Server   │  │  Server   │  │  Server   │  ... x 500   │
  │  │  ECDSA    │  │  ECDSA    │  │  ECDSA    │              │
  │  └───────────┘  └───────────┘  └───────────┘              │
  │                                                             │
  │  ┌───────────┐  ┌───────────┐  ┌───────────┐              │
  │  │  Client   │  │  Client   │  │  Client   │  ... x 9500  │
  │  │  Legacy   │  │  Legacy   │  │  Modern   │              │
  │  │  (ECDSA)  │  │  (ECDSA)  │  │  (PQC OK) │              │
  │  └───────────┘  └───────────┘  └───────────┘              │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘

  How to migrate without cutting service?
```

---

## The Problem

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  "BIG BANG" MIGRATION: Risk of massive outage                   │
│                                                                  │
│                                                                  │
│    Day D: Migration to ML-DSA                                   │
│                                                                  │
│       ┌─────────┐         ┌─────────┐                           │
│       │ Server  │  ❌───► │ Client  │  Doesn't understand ML-DSA│
│       │ ML-DSA  │         │ Legacy  │                           │
│       └─────────┘         └─────────┘                           │
│                                                                  │
│    Result:                                                       │
│    - 80% of clients can't connect anymore                       │
│    - Massive outage                                              │
│    - Rollback required                                           │
│    - Migration delayed 6 months                                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## The Solution: CA Rotation with Trust Bundles

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  CA VERSIONING                                                  │
│  ─────────────                                                  │
│                                                                  │
│  Migration CA                                                    │
│  ├── v1 (ECDSA)     ──► archived                                │
│  ├── v2 (Hybrid)    ──► archived                                │
│  └── v3 (ML-DSA)    ──► active                                  │
│                                                                  │
│  Key Insight:                                                    │
│  - ONE logical CA with MULTIPLE cryptographic versions          │
│  - Old certificates remain valid after rotation                  │
│  - Trust bundles allow gradual client migration                  │
│                                                                  │
│  PKI reality: Each version has its own key. "Versioning" is     │
│  an operational abstraction over distinct trust anchors.        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Trust Store Strategy

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  TRUST STORE DEPLOYMENT                                         │
│                                                                  │
│  Clients Legacy ── trust-legacy.pem ──► CA v1 ──► Cert v1       │
│  Clients Modern ── trust-modern.pem ──► CA v3 ──► Cert v3       │
│                                                                  │
│  Transition :                                                    │
│  Clients ── trust-transition.pem ──► CA v1 / v2 / v3            │
│                                                                  │
│  During migration:                                               │
│  - Publish trust-transition.pem (contains ALL CA versions)      │
│  - ALL certificates validate correctly                          │
│  - Clients upgrade at their own pace                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

> **Important:** The trust bundle is a *temporary migration artifact*.
> It should be removed once all clients have migrated to PQC.

---

## What is Crypto-Agility?

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  CRYPTO-AGILITY                                                │
│  ──────────────                                                │
│                                                                 │
│  The ability of a system to:                                   │
│                                                                 │
│  1. CHANGE algorithm                                           │
│     → Without redesigning the architecture                     │
│                                                                 │
│  2. SUPPORT multiple algorithms                                │
│     → During transition                                        │
│                                                                 │
│  3. ROLLBACK quickly                                           │
│     → If a problem occurs                                      │
│                                                                 │
│  It's an ARCHITECTURAL PROPERTY, not a tool.                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## What We'll Do

1. Create Migration CA (ECDSA)
1b. Issue ECDSA server certificate
2. Rotate CA to hybrid (ECDSA + ML-DSA)
2b. Rotate credential to hybrid
3. Rotate CA to full PQC (ML-DSA)
3b. Rotate credential to PQC
4. Create trust stores
5. Verify certificates against trust stores
6. Simulate rollback

---

## Run the Demo

```bash
./journey/10-crypto-agility/demo.sh
```

---

## The Commands

### Step 1: Create Migration CA (ECDSA)

```bash
# Create a Migration CA starting with ECDSA
qpki ca init --profile profiles/classic-ca.yaml \
    --var cn="Migration CA" \
    --ca-dir output/ca
```

### Step 1b: Issue ECDSA Server Certificate (v1)

```bash
# Issue ECDSA server certificate
qpki credential enroll --ca-dir output/ca \
    --cred-dir output/credentials \
    --profile profiles/classic-tls-server.yaml \
    --var cn=server.example.com

qpki credential export <credential-id> \
    --ca-dir output/ca \
    --cred-dir output/credentials \
    --out output/server-v1.pem
```

### Step 2: Rotate to Hybrid CA

```bash
# Rotate to hybrid mode (ECDSA + ML-DSA)
qpki ca rotate --ca-dir output/ca \
    --profile profiles/hybrid-ca.yaml

qpki ca activate --ca-dir output/ca --version v2

qpki ca versions --ca-dir output/ca
# v1       archived  ecdsa-p256
# v2       active    ecdsa-p256+ml-dsa-65
```

### Step 2b: Rotate Credential to Hybrid

```bash
# Same server, new algorithm — zero downtime migration
qpki credential rotate <credential-id> \
    --ca-dir output/ca \
    --cred-dir output/credentials \
    --profile profiles/hybrid-tls-server.yaml

qpki credential export <credential-id> \
    --ca-dir output/ca \
    --cred-dir output/credentials \
    --out output/server-v2.pem
```

### Step 3: Rotate to Full PQC CA

```bash
# Rotate to full post-quantum
qpki ca rotate --ca-dir output/ca \
    --profile profiles/pqc-ca.yaml

qpki ca activate --ca-dir output/ca --version v3

qpki ca versions --ca-dir output/ca
# v1       archived  ecdsa-p256
# v2       archived  ecdsa-p256+ml-dsa-65
# v3       active    ml-dsa-65
```

### Step 3b: Rotate Credential to PQC

```bash
# Final migration — full post-quantum
qpki credential rotate <credential-id> \
    --ca-dir output/ca \
    --cred-dir output/credentials \
    --profile profiles/pqc-tls-server.yaml

qpki credential export <credential-id> \
    --ca-dir output/ca \
    --cred-dir output/credentials \
    --out output/server-v3.pem
```

### Step 4: Create Trust Stores

```bash
# Trust store for legacy clients (v1 only)
qpki ca export --ca-dir output/ca --version v1 --out output/trust-legacy.pem

# Trust store for modern PQC-capable clients (v3 only)
qpki ca export --ca-dir output/ca --version v3 --out output/trust-modern.pem

# Trust store for transition period (all versions - enables gradual migration)
qpki ca export --ca-dir output/ca --all --out output/trust-transition.pem
```

### Step 5: Verify Certificates Against Trust Stores

```bash
# Full interoperability matrix: every cert × every trust store
# OK = cert was signed by a CA in the trust store
# FAIL = expected — proves trust isolation works correctly

qpki cert verify output/server-v1.pem --ca output/trust-legacy.pem       # ✓ OK
qpki cert verify output/server-v1.pem --ca output/trust-transition.pem   # ✓ OK
qpki cert verify output/server-v1.pem --ca output/trust-modern.pem       # ✗ FAIL

qpki cert verify output/server-v2.pem --ca output/trust-legacy.pem       # ✗ FAIL
qpki cert verify output/server-v2.pem --ca output/trust-transition.pem   # ✓ OK
qpki cert verify output/server-v2.pem --ca output/trust-modern.pem       # ✗ FAIL

qpki cert verify output/server-v3.pem --ca output/trust-legacy.pem       # ✗ FAIL
qpki cert verify output/server-v3.pem --ca output/trust-transition.pem   # ✓ OK
qpki cert verify output/server-v3.pem --ca output/trust-modern.pem       # ✓ OK
```

```
INTEROPERABILITY MATRIX
───────────────┬─────────────────────┬─────────
  Certificate  │  Trust Store        │  Result
───────────────┼─────────────────────┼─────────
  v1 (ECDSA)   │  trust-legacy       │  ✓ OK
  v1 (ECDSA)   │  trust-transition   │  ✓ OK
  v1 (ECDSA)   │  trust-modern       │  ✗ FAIL
  v2 (Hybrid)  │  trust-legacy       │  ✗ FAIL
  v2 (Hybrid)  │  trust-transition   │  ✓ OK
  v2 (Hybrid)  │  trust-modern       │  ✗ FAIL
  v3 (ML-DSA)  │  trust-legacy       │  ✗ FAIL
  v3 (ML-DSA)  │  trust-transition   │  ✓ OK
  v3 (ML-DSA)  │  trust-modern       │  ✓ OK
───────────────┴─────────────────────┴─────────

Key insight: Each cert only works with trust stores containing its CA version.
The transition bundle is the key to gradual migration — all certs work.
FAIL is expected: it proves trust isolation works correctly.
```

### Step 6: Simulate Rollback

```bash
# Scenario: A compatibility issue is detected on legacy appliances.
# Solution: Rollback to Hybrid CA (v2) - the "best of both worlds"
#
# Why v2 (Hybrid) is ideal for rollback:
# - Legacy clients can still verify using ECDSA
# - Modern clients benefit from PQC protection
# - No certificates are invalidated

qpki ca activate --ca-dir output/ca --version v2

qpki ca versions --ca-dir output/ca
# v1       archived  ecdsa-p256
# v2       active    ecdsa-p256+ml-dsa-65    <-- rolled back here
# v3       archived  ml-dsa-65
```

---

## Crypto-Agility Checklist

| Question | Crypto-Agile | Not Crypto-Agile |
|----------|--------------|------------------|
| Are algorithms configured or hardcoded? | Configured | Hardcoded |
| Can you change algo without rebuild? | Yes | No |
| Do certs support multiple algos? | Yes (hybrid) | No |
| Can you rollback in < 1h? | Yes | No |
| Is crypto inventory automated? | Yes | Manual |

---

## Size Comparison

| Phase | Algorithm | CA Cert | Server Cert | Notes |
|-------|-----------|---------|-------------|-------|
| Phase 1 | ECDSA P-256 | ~600 B | ~800 B | Compact |
| Phase 2 | ECDSA + ML-DSA | ~5 KB | ~6 KB | Hybrid |
| Phase 3 | ML-DSA-65 | ~4 KB | ~5 KB | Full PQC |

*Size increase is usually negligible compared to TLS records, HTTP payloads, or firmware images.*

---

## What You Learned

1. **Crypto-agility** is the ability to change algorithms without breaking your system
2. **CA rotation** allows evolving cryptographic algorithms over time
3. **Trust bundles** enable gradual client migration
4. **Old certificates remain valid** after CA rotation
5. **Rollback is always possible** - reactivate older versions
6. **Never do "big bang"** migration - it's too risky
7. **You're ready:** You now have the knowledge to plan and execute a PQC migration.

---

## References

- [NIST Post-Quantum Cryptography](https://csrc.nist.gov/projects/post-quantum-cryptography)
- [NIST FIPS 204: ML-DSA Standard](https://csrc.nist.gov/pubs/fips/204/final)
- [Catalyst Hybrid Certificates](https://www.ietf.org/archive/id/draft-ounsworth-pq-composite-sigs-13.html)

---

← [CMS Encryption](../09-cms-encryption/) | [QLAB Home](../../README.md)

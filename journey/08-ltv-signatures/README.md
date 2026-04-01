---
title: "Lab-08: PQC LTV Signatures"
description: "Build long-term validation bundles that package all proofs for offline verification decades later, without external dependencies."
---

# Lab-08: PQC LTV Signatures

## Long-Term Validation for Document Signing

> **Key Message:** LTV bundles all proofs for offline verification in 2055. A signature is only as good as its proof chain.

**Important distinction:** Timestamping is necessary but **not sufficient** for long-term validation. A timestamp proves WHEN something was signed. LTV proves that **all trust elements** (certificates, revocation status, timestamps) were valid at that time — and bundles them for offline verification.

---

## The Scenario

*"We signed a 30-year contract today. In 2055, how will anyone verify this signature if our CA no longer exists?"*

This is the **Long-Term Validation (LTV)** problem. A signature alone isn't enough — you need proof that the certificate was valid at the time of signing.

---

## The Problem

```
TODAY (2024)                         IN 30 YEARS (2054)
────────────                         ──────────────────

┌────────────────┐                   ┌────────────────┐
│  Contract.pdf  │                   │  Contract.pdf  │
│  + Signature   │                   │  + Signature   │
│                │                   │                │
│  Services:     │    ────────────►  │  Services:     │
│  ✓ CA online   │                   │  ❌ CA dissolved │
│  ✓ OCSP online │                   │  ❌ OCSP down    │
│  ✓ Cert valid  │                   │  ❌ Cert expired │
└────────────────┘                   └────────────────┘

                                     How to verify
                                     the signature?
```

---

## The Threat

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  "PERISHABLE" SIGNATURE: Dependency on external services        │
│                                                                  │
│                                                                  │
│    2024                2034                2054                  │
│      │                   │                   │                   │
│      │  Signature        │  Cert expired     │  Verification?   │
│      │  created          │                   │                   │
│      ▼                   ▼                   ▼                   │
│                                                                  │
│    ┌───────┐           ┌───────┐           ┌───────┐            │
│    │  OK   │           │  ???  │           │  ???  │            │
│    └───────┘           └───────┘           └───────┘            │
│                                                                  │
│    To verify in 2054, you would need:                           │
│    - The certificate (expired)                                   │
│    - The OCSP response (service down)                           │
│    - The CA chain (company dissolved)                           │
│    - The timestamp (TSA migrated)                               │
│                                                                  │
│    → IMPOSSIBLE without preparation                              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## The Solution: LTV (Long-Term Validation)

Embed EVERYTHING needed in a self-sufficient bundle:

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  LTV BUNDLE: Self-sufficient verification package               │
│                                                                  │
│                                                                  │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  LTV Bundle                                              │  │
│    │  ──────────────                                          │  │
│    │                                                          │  │
│    │  1. Original document                                    │  │
│    │     └── contract.txt                                     │  │
│    │                                                          │  │
│    │  2. Signature                                            │  │
│    │     └── signature.p7s (ML-DSA CMS)                      │  │
│    │                                                          │  │
│    │  3. Timestamp                                            │  │
│    │     └── timestamp.tsr (proves WHEN it was signed)       │  │
│    │                                                          │  │
│    │  4. Certificate chain                                    │  │
│    │     └── chain.pem (signer + CA certs)                   │  │
│    │                                                          │  │
│    │  5. Manifest                                             │  │
│    │     └── manifest.json (metadata)                        │  │
│    │                                                          │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│    VERIFICATION IN 2054:                                         │
│    ✓ Everything is embedded                                      │
│    ✓ No external dependencies                                    │
│    ✓ OFFLINE verification possible                               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## LTV Components

| Component | Role | Why Needed |
|-----------|------|------------|
| **Signature** | Document authenticity | Proves WHO signed |
| **Timestamp** | Temporal proof | Proves WHEN it was signed |
| **Certificate chain** | Trust anchor | Allows tracing to root CA |
| **Manifest** | Metadata | Documents the bundle structure |

**Note:** In production-grade LTV (CAdES-LT/LTA, PAdES-LTV), OCSP responses and CRLs are also embedded to prove revocation status at signing time.

---

## What We'll Do

1. Create a CA for document signing
1b. Issue TSA certificate
1c. Issue signing certificate
2. Start TSA server
3. Create document
3b. Sign document
3c. Request a timestamp (via HTTP)
4. Create an LTV bundle
5. Verify offline (simulating 2055)
6. Stop TSA server

---

## Run the Demo

```bash
./journey/08-ltv-signatures/demo.sh
```

---

## The Commands

### Step 1: Create CA

```bash
# Create PQC CA
qpki ca init --profile profiles/pqc-ca.yaml \
    --var cn="LTV Demo CA" \
    --ca-dir output/ltv-ca

qpki ca export --ca-dir output/ltv-ca --out output/ltv-ca/ca.crt
```

### Step 1b: Issue TSA Certificate

```bash
# Generate TSA key and CSR
qpki csr gen --algorithm ml-dsa-65 \
    --keyout output/tsa.key \
    --cn "LTV Timestamp Authority" \
    --out output/tsa.csr

qpki cert issue --ca-dir output/ltv-ca \
    --profile profiles/pqc-tsa.yaml \
    --csr output/tsa.csr \
    --out output/tsa.crt
```

### Step 2: Start TSA Server

```bash
# Start RFC 3161 HTTP timestamp server
qpki tsa serve --port 8318 \
    --cert output/tsa.crt \
    --key output/tsa.key
```

### Step 1c: Issue Signing Certificate

```bash
# Generate document signing key and CSR (Alice)
qpki csr gen --algorithm ml-dsa-65 \
    --keyout output/alice.key \
    --cn "Alice (Legal Counsel)" \
    --out output/alice.csr

qpki cert issue --ca-dir output/ltv-ca \
    --profile profiles/pqc-document-signing.yaml \
    --csr output/alice.csr \
    --out output/alice.crt
```

### Step 3: Create Document

```bash
# Create a 30-year lease agreement
cat > output/contract.txt << 'EOF'
30-YEAR COMMERCIAL LEASE AGREEMENT
Signing Date: 2024-12-22
Expiration: 2054-12-22
Parties: ACME Properties / TechCorp Industries
EOF
```

### Step 3b: Sign Document

```bash
qpki cms sign --data output/contract.txt \
    --cert output/alice.crt \
    --key output/alice.key \
    --out output/contract.p7s
```

### Step 3c: Request Timestamp (via HTTP)

```bash
# Create timestamp request
qpki tsa request --data output/contract.p7s \
    --out output/request.tsq

curl -s -X POST \
    -H "Content-Type: application/timestamp-query" \
    --data-binary @output/request.tsq \
    http://localhost:8318/ \
    -o output/contract.tsr
```

### Step 4: Create LTV Bundle

```bash
# LTV Bundle contains everything needed for offline verification:
# - document.txt: original content
# - signature.p7s: proves WHO signed
# - timestamp.tsr: proves WHEN signed
# - chain.pem: proves trust path (signer → CA)
mkdir -p output/ltv-bundle
cp output/contract.txt output/ltv-bundle/document.txt
cp output/contract.p7s output/ltv-bundle/signature.p7s
cp output/contract.tsr output/ltv-bundle/timestamp.tsr
cat output/alice.crt output/ltv-ca/ca.crt > output/ltv-bundle/chain.pem
```

### Step 5: Verify Offline (Simulating 2055)

```bash
# Verify using only the bundle (no network)
qpki cms verify output/ltv-bundle/signature.p7s \
    --data output/ltv-bundle/document.txt \
    --ca output/ltv-bundle/chain.pem
# Result: VALID - signature verified with bundled chain
```

### Step 6: Stop TSA Server

```bash
# Stop the TSA server
qpki tsa stop --port 8318
```

---

## PAdES-LTV Format (PDF)

For PDF documents, LTV data is stored in a Document Security Store (DSS):

```
PDF Document with LTV
─────────────────────

┌─────────────────────────────────────────────────────────────┐
│  PDF Document                                               │
│  ├── Page 1, 2, 3...                                       │
│  │                                                          │
│  └── DSS (Document Security Store)                         │
│      ├── Certs[]                                           │
│      │   ├── signing-cert.der                              │
│      │   ├── issuing-ca.der                                │
│      │   ├── root-ca.der                                   │
│      │   └── tsa-cert.der                                  │
│      │                                                      │
│      ├── OCSPs[]                                           │
│      │   └── ocsp-response.der                             │
│      │                                                      │
│      └── CRLs[]                                            │
│          └── ca.crl (optional)                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Why PQC for LTV

### The 30-Year Timeline Problem

```
2024                    2035?                   2054
  │                       │                       │
  │  Sign document        │  Quantum computers    │  Verify signature
  │  with ML-DSA          │  break RSA/ECDSA      │
  │                       │                       │
  ▼                       ▼                       ▼

Classical signature:    FORGEABLE!              Cannot trust
ML-DSA signature:       Still secure            ✓ VERIFIED
```

### Long-Term Document Retention

| Document Type | Retention Period | PQC Required? |
|--------------|------------------|---------------|
| Legal contracts | 10-30 years | **Yes** |
| Medical records | 50+ years | **Yes** |
| Real estate deeds | Permanent | **Yes** |
| Notarial acts | 75 years | **Yes** |
| Financial audits | 7-10 years | Yes |
| Patents | 20+ years | **Yes** |

---

## What You Learned

1. **Signatures expire**: Without LTV, signatures become unverifiable
2. **LTV bundles proofs**: Document + signature + timestamp + chain
3. **Offline verification**: No network dependencies in 2055
4. **PQC is essential**: 30-year documents will face quantum computers

---

## References

- [RFC 5126: CMS Advanced Electronic Signatures (CAdES)](https://datatracker.ietf.org/doc/html/rfc5126)
- [ETSI TS 101 733: Electronic Signatures](https://www.etsi.org/deliver/etsi_ts/101700_101799/101733/)
- [PAdES: PDF Advanced Electronic Signatures](https://www.etsi.org/deliver/etsi_en/319100_319199/31914201/)
- [NIST FIPS 204: ML-DSA Standard](https://csrc.nist.gov/pubs/fips/204/final)

---

← [PQC Timestamping](../07-timestamping/) | [QLAB Home](../../README.md) | [Next: CMS Encryption →](../09-cms-encryption/)

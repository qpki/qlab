---
title: "Troubleshooting"
description: "Common issues and solutions when working with post-quantum PKI"
---

# Troubleshooting

Common issues and solutions when working with post-quantum PKI.

---

## Common Errors

### Certificate too large for application

**Symptom:** Application rejects PQC certificate or connection fails.

**Cause:** PQC certificates are ~6x larger than classical certificates.

| Certificate Type | Classical (ECDSA) | PQC (ML-DSA-65) |
|------------------|-------------------|-----------------|
| Single cert | ~1 KB | ~6 KB |
| Full chain | ~3 KB | ~19 KB |

**Solutions:**
1. Check application/protocol limits (some have 16 KB max)
2. Use ML-DSA-44 instead of ML-DSA-65 for constrained environments
3. Consider hybrid certificates for transition period

---

### Client doesn't support ML-DSA

**Symptom:** `unknown algorithm` or `unsupported signature algorithm` error.

**Cause:** Client library doesn't support FIPS 204 (ML-DSA).

**Solutions:**
1. Use hybrid certificates (Lab-03) — legacy clients use ECDSA, modern clients verify both
2. Update client libraries to versions supporting PQC
3. Check [Qpki compatibility matrix](https://github.com/qpki/qpki#compatibility)

---

### Chain verification fails

**Symptom:** `certificate verify failed` or `unable to get issuer certificate`.

**Cause:** Missing intermediate CA or algorithm mismatch.

**Diagnostic:**
```bash
# Inspect certificate chain
qpki chain verify --cert server.crt --ca-bundle ca-chain.pem

# Check certificate details
qpki inspect server.crt
```

**Solutions:**
1. Ensure full chain is provided (Root + Issuing + End-entity)
2. Verify all certificates use compatible algorithms
3. Check certificate validity dates

---

### CSR attestation fails (ML-KEM)

**Symptom:** `attestation verification failed` when issuing encryption certificate.

**Cause:** ML-KEM keys cannot sign their own CSR (see Lab-09).

**Solution:**
```bash
# Use signing certificate to attest for KEM key
qpki csr gen --algorithm ml-kem-768 \
    --attest-cert alice-sign.crt \
    --attest-key alice-sign.key \
    --out alice-enc.csr
```

---

## Diagnostic Commands

### Inspect certificate

```bash
# QPKI inspection (human-readable)
qpki inspect certificate.crt

# OpenSSL detailed output
openssl x509 -in certificate.crt -text -noout

# Check algorithm
openssl x509 -in certificate.crt -noout -text | grep "Signature Algorithm"
```

### Verify chain

```bash
# Verify full chain
qpki chain verify \
    --cert end-entity.crt \
    --intermediate issuing-ca.crt \
    --root root-ca.crt

# OpenSSL verification
openssl verify -CAfile ca-chain.pem certificate.crt
```

### Check CRL/OCSP status

```bash
# Check CRL
qpki crl inspect --ca-dir ./ca

# OCSP request
qpki ocsp request \
    --cert certificate.crt \
    --issuer issuing-ca.crt \
    --url http://localhost:8080/ocsp
```

---

## FAQ

### When should I migrate to PQC?

Use Mosca's inequality (Lab-01):

```
Migration Time + Data Shelf Life > Time to Quantum Computer
```

If your data must remain confidential for 10+ years, start now.

### Can I mix algorithms in a certificate chain?

**Yes**, but with caveats:
- Root CA can use different algorithm than Issuing CA
- The signature on each certificate must be verifiable by the parent's algorithm
- Example: Root (ML-DSA-87) → Issuing (ML-DSA-65) → End-entity (ML-DSA-65)

### How to rollback if PQC breaks something?

Use CA versioning (Lab-10):

```bash
# Export previous CA version
qpki ca export --ca-dir ./ca --version v1

# Clients can trust multiple versions during transition
```

### Why are PQC signatures so large?

| Algorithm | Signature Size | Why |
|-----------|---------------|-----|
| ECDSA P-384 | 96 bytes | Elliptic curve math |
| ML-DSA-65 | 3,309 bytes | Lattice-based (quantum-resistant) |
| SLH-DSA-128s | ~7,856 bytes | Hash-based (conservative) |

The size increase is the trade-off for quantum resistance.

---

## Getting Help

- [Qpki Documentation](https://github.com/qpki/qpki)
- [Qlab Issues](https://github.com/qpki/qlab/issues)
- [NIST PQC FAQ](https://csrc.nist.gov/projects/post-quantum-cryptography/faqs)

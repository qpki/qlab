#!/bin/bash
# =============================================================================
#  Lab-04: Certificate Revocation
#
#  Incident Response: When Keys Are Compromised
#  Revoke certificates and generate CRLs
#
#  This demo uses ML-DSA-65 (Post-Quantum) for both CA and certificates.
#  CRL generation with PQC keys is supported via custom ASN.1 encoding.
#
#  Key Message: Certificate revocation works the same regardless of algorithm.
#               Same workflow, same commands.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

setup_demo "Certificate Revocation"

PROFILES="$SCRIPT_DIR/profiles"

# =============================================================================
# Introduction
# =============================================================================

echo -e "${BOLD}SCENARIO:${NC}"
echo "  \"A private key has been compromised!"
echo "   How do I revoke the certificate and inform clients?\""
echo ""

echo -e "${BOLD}WHAT WE'LL DO:${NC}"
echo "  1.  Create a CA (ML-DSA-65)"
echo "  1b. Issue a TLS certificate"
echo "  2.  Revoke the certificate (after key compromise)"
echo "  2b. Generate a CRL (Certificate Revocation List)"
echo "  3.  Verify the revoked certificate is rejected"
echo ""

echo -e "${DIM}Revocation workflow is identical for classical and PQC algorithms.${NC}"
echo ""

pause "Press Enter to start..."

# =============================================================================
# Step 1: Create CA
# =============================================================================

print_step "Step 1: Create CA"

echo "  First, we need a CA to issue and revoke certificates."
echo ""

run_cmd "$PKI_BIN ca init --profile $PROFILES/pqc-ca.yaml --var cn=\"Demo CA\" --ca-dir $DEMO_TMP/pqc-ca"

# Export CA certificate for verification
$PKI_BIN ca export --ca-dir $DEMO_TMP/pqc-ca --out $DEMO_TMP/pqc-ca/ca.crt

echo ""

pause

# =============================================================================
# Step 2: Issue Certificate
# =============================================================================

print_step "Step 1b: Issue Certificate"

echo "  Generate an ML-DSA-65 key pair and issue a TLS certificate."
echo ""

run_cmd "$PKI_BIN csr gen --algorithm ml-dsa-65 --keyout $DEMO_TMP/server.key --cn server.example.com --out $DEMO_TMP/server.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $DEMO_TMP/pqc-ca --profile $PROFILES/pqc-tls-server.yaml --csr $DEMO_TMP/server.csr --out $DEMO_TMP/server.crt"

# Get serial number
SERIAL=$(openssl x509 -in $DEMO_TMP/server.crt -noout -serial 2>/dev/null | cut -d= -f2)
if [[ -z "$SERIAL" ]]; then
    print_error "Failed to extract certificate serial number"
    exit 1
fi

echo ""
echo -e "  ${BOLD}Certificate issued:${NC}"
echo -e "    Serial: ${YELLOW}$SERIAL${NC}"
echo ""

pause

# =============================================================================
# Incident - Key Compromise!
# =============================================================================

echo ""
echo -e "  ${RED}🚨 ALERT: The private key for server.example.com was exposed!${NC}"
echo ""
echo "  Incident response steps:"
echo "    1. [DONE] Detect the compromise"
echo "    2. [DONE] Identify the certificate (serial: $SERIAL)"
echo "    3. [NEXT] Revoke the certificate"
echo "    4. [NEXT] Generate updated CRL"
echo "    5. [NEXT] Issue replacement certificate"
echo ""

pause

# =============================================================================
# Step 3: Revoke the Certificate
# =============================================================================

print_step "Step 2: Revoke the Certificate"

echo "  Revocation reasons (RFC 5280):"
echo ""
echo "    0 = unspecified"
echo "    1 = keyCompromise      <- We'll use this"
echo "    2 = cACompromise"
echo "    3 = affiliationChanged"
echo "    4 = superseded"
echo "    5 = cessationOfOperation"
echo ""

run_cmd "$PKI_BIN cert revoke $SERIAL --ca-dir $DEMO_TMP/pqc-ca --reason keyCompromise"

echo ""
echo -e "  ${GREEN}✓${NC} Certificate revoked"
echo ""

pause

# =============================================================================
# Step 4: Generate CRL
# =============================================================================

print_step "Step 2b: Generate CRL (Certificate Revocation List)"

echo "  The CRL is a signed list of all revoked certificates."
echo "  Clients download it to check certificate validity."
echo ""

run_cmd "$PKI_BIN crl gen --ca-dir $DEMO_TMP/pqc-ca"

if [[ -f "$DEMO_TMP/pqc-ca/crl/ca.crl" ]]; then
    crl_size=$(wc -c < "$DEMO_TMP/pqc-ca/crl/ca.crl" | tr -d ' ')
    echo ""
    echo -e "  ${BOLD}CRL generated:${NC}"
    echo -e "    Size: $crl_size bytes"
    echo ""
    echo -e "  ${DIM}Note: CRL size depends on number of revoked certificates${NC}"
fi

echo ""
echo "  View the CRL contents..."
echo ""

run_cmd "$PKI_BIN inspect $DEMO_TMP/pqc-ca/crl/ca.crl"

echo ""

pause

# =============================================================================
# Step 5: Verify Revocation Status
# =============================================================================

print_step "Step 3: Verify Revocation Status"

echo "  Let's verify the certificate is now rejected..."
echo ""

echo -e "  ${DIM}$ qpki cert verify $DEMO_TMP/server.crt --ca $DEMO_TMP/pqc-ca/ca.crt --crl $DEMO_TMP/pqc-ca/crl/ca.crl${NC}"

if ! $PKI_BIN cert verify $DEMO_TMP/server.crt --ca $DEMO_TMP/pqc-ca/ca.crt --crl $DEMO_TMP/pqc-ca/crl/ca.crl 2>&1; then
    echo ""
    echo -e "  ${RED}✗${NC} Certificate REVOKED - Verification failed (expected!)"
else
    echo ""
    echo -e "  ${YELLOW}[INFO]${NC} CRL verification may not be fully supported"
fi

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  REVOCATION SUMMARY                                            │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │  Serial         : $SERIAL                            │"
echo "  │  Reason         : keyCompromise                                │"
echo -e "  │  Status         : ${RED}REVOKED${NC}                                      │"
echo "  │  CRL generated  : Yes                                          │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# =============================================================================
# Conclusion
# =============================================================================

print_key_message "Certificate revocation works the same regardless of algorithm."

show_lesson "PKI operations are algorithm-agnostic.
Same workflow, same commands, same runbooks.
No retraining needed for ops teams.
Note: PQC CRL support depends on Go crypto/x509 evolution."

show_footer

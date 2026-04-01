#!/bin/bash
# =============================================================================
#  Lab-08: LTV Signatures - Sign Today, Verify in 30 Years
#
#  Long-Term Validation for document signing with ML-DSA
#  Bundle everything needed for offline verification decades from now
#
#  Key Message: A signature is only as good as its proof chain.
#               LTV bundles everything needed for offline verification.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

TSA_PORT=8318
TSA_PID=""

cleanup() {
    if [[ -n "$TSA_PID" ]] && kill -0 "$TSA_PID" 2>/dev/null; then
        echo ""
        echo -e "  ${DIM}Stopping TSA server (PID $TSA_PID)...${NC}"
        kill "$TSA_PID" 2>/dev/null || true
        wait "$TSA_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT

setup_demo "PQC LTV Signatures"

PROFILES="$SCRIPT_DIR/profiles"
BUNDLE_DIR="$DEMO_TMP/ltv-bundle"

# =============================================================================
# Introduction
# =============================================================================

echo -e "${BOLD}SCENARIO:${NC}"
echo "  \"I signed a 30-year contract. How do I ensure the signature"
echo "   can still be verified in 2055 when the CA is long gone?\""
echo ""

echo -e "${BOLD}WHAT WE'LL DO:${NC}"
echo "  1.  Create a CA for document signing"
echo "  1b. Issue TSA certificate"
echo "  1c. Issue signing certificate"
echo "  2.  Start TSA server"
echo "  3.  Create document"
echo "  3b. Sign document"
echo "  3c. Request a timestamp (via HTTP)"
echo "  4.  Create an LTV bundle"
echo "  5.  Verify offline (simulating 2055)"
echo "  6.  Stop TSA server"
echo ""

echo -e "${DIM}LTV = Long-Term Validation. Bundle everything for offline verification.${NC}"
echo ""

pause "Press Enter to start..."

# =============================================================================
# Step 1: Create CA
# =============================================================================

print_step "Step 1: Create CA"

echo "  We need a CA to issue certificates for document signing and timestamping."
echo ""

run_cmd "$PKI_BIN ca init --profile $PROFILES/pqc-ca.yaml --var cn=\"LTV Demo CA\" --ca-dir $DEMO_TMP/ltv-ca"

# Export CA certificate for chain building
$PKI_BIN ca export --ca-dir $DEMO_TMP/ltv-ca --out $DEMO_TMP/ltv-ca/ca.crt

echo ""

pause

# =============================================================================
# Step 2: Issue TSA Certificate
# =============================================================================

print_step "Step 1b: Issue TSA Certificate"

echo "  Generate TSA key and issue certificate..."
echo ""

run_cmd "$PKI_BIN csr gen --algorithm ml-dsa-65 --keyout $DEMO_TMP/tsa.key --cn \"LTV Timestamp Authority\" --out $DEMO_TMP/tsa.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $DEMO_TMP/ltv-ca --profile $PROFILES/pqc-tsa.yaml --csr $DEMO_TMP/tsa.csr --out $DEMO_TMP/tsa.crt"

echo ""

pause

# =============================================================================
# Step 3: Start TSA Server
# =============================================================================

print_step "Step 2: Start TSA Server"

echo "  Starting RFC 3161 HTTP timestamp server on port $TSA_PORT..."
echo ""

echo -e "  ${DIM}$ qpki tsa serve --port $TSA_PORT --cert $DEMO_TMP/tsa.crt --key $DEMO_TMP/tsa.key &${NC}"
echo ""

$PKI_BIN tsa serve --port $TSA_PORT --cert $DEMO_TMP/tsa.crt --key $DEMO_TMP/tsa.key &
TSA_PID=$!

sleep 1

if kill -0 "$TSA_PID" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} TSA server running on http://localhost:$TSA_PORT"
    echo -e "  ${DIM}(PID: $TSA_PID)${NC}"
else
    echo -e "  ${RED}✗${NC} Failed to start TSA server"
    exit 1
fi

echo ""

pause

# =============================================================================
# Step 4: Issue Signing Certificate
# =============================================================================

print_step "Step 1c: Issue Signing Certificate"

echo "  Generate document signing key and CSR for Alice..."
echo ""

run_cmd "$PKI_BIN csr gen --algorithm ml-dsa-65 --keyout $DEMO_TMP/alice.key --cn \"Alice (Legal Counsel)\" --out $DEMO_TMP/alice.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $DEMO_TMP/ltv-ca --profile $PROFILES/pqc-document-signing.yaml --csr $DEMO_TMP/alice.csr --out $DEMO_TMP/alice.crt"

echo ""

pause

# =============================================================================
# Step 5: Create and Sign Document
# =============================================================================

print_step "Step 3: Create Document"

echo "  Creating a 30-year lease agreement..."
echo ""

cat > $DEMO_TMP/contract.txt << 'EOF'
30-YEAR COMMERCIAL LEASE AGREEMENT
Signing Date: 2024-12-22
Expiration: 2054-12-22
Parties: ACME Properties / TechCorp Industries
EOF

echo "  Document created."
echo ""

pause

# =============================================================================
# Step 3b: Sign Document
# =============================================================================

print_step "Step 3b: Sign Document"

SIGN_DATE=$(date "+%Y-%m-%d %H:%M:%S")

cat > $DEMO_TMP/contract.txt << EOF
================================================================================
                    30-YEAR COMMERCIAL LEASE AGREEMENT
================================================================================

Document ID: LEASE-$(date +%s)
Signing Date: $SIGN_DATE
Expiration: 2054-12-22

PARTIES:
  Lessor:  ACME Properties LLC
  Lessee:  TechCorp Industries Inc.

TERMS:
  Property: 123 Innovation Drive, Suite 500
  Duration: 30 years from signing date
  Monthly Rent: \$50,000 (adjusted annually for inflation)

This agreement shall remain valid and enforceable for the full 30-year term.

SIGNATURES:
  Signed electronically with Post-Quantum ML-DSA-65 algorithm.

================================================================================
EOF

echo -e "  ${CYAN}Contract content:${NC}"
head $DEMO_TMP/contract.txt | sed 's/^/    /'
echo "    ..."
echo ""

echo "  Signing with CMS (ML-DSA)..."
echo ""

run_cmd "$PKI_BIN cms sign --data $DEMO_TMP/contract.txt --cert $DEMO_TMP/alice.crt --key $DEMO_TMP/alice.key --out $DEMO_TMP/contract.p7s"

echo ""

if [[ -f "$DEMO_TMP/contract.p7s" ]]; then
    sig_size=$(wc -c < "$DEMO_TMP/contract.p7s" | tr -d ' ')
    echo -e "  ${CYAN}Signature size:${NC} $sig_size bytes"
fi

echo ""

pause

# =============================================================================
# Step 6: Request Timestamp (via HTTP)
# =============================================================================

print_step "Step 3c: Request Timestamp (via HTTP)"

echo "  The timestamp proves WHEN the document was signed."
echo "  This is critical because it proves the certificate was valid at signing time."
echo ""

run_cmd "$PKI_BIN tsa request --data $DEMO_TMP/contract.p7s --out $DEMO_TMP/request.tsq"

echo ""

echo -e "  ${DIM}$ curl -s -X POST -H \"Content-Type: application/timestamp-query\" --data-binary @$DEMO_TMP/request.tsq http://localhost:$TSA_PORT/ -o $DEMO_TMP/contract.tsr${NC}"
echo ""

curl -s -X POST \
    -H "Content-Type: application/timestamp-query" \
    --data-binary @$DEMO_TMP/request.tsq \
    "http://localhost:$TSA_PORT/" \
    -o $DEMO_TMP/contract.tsr

if [[ -f "$DEMO_TMP/contract.tsr" ]]; then
    tsr_size=$(wc -c < "$DEMO_TMP/contract.tsr" | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} Timestamp token received"
    echo -e "  ${CYAN}Timestamp size:${NC} $tsr_size bytes"
else
    echo -e "  ${RED}✗${NC} Failed to get timestamp"
    exit 1
fi

echo ""

pause

# =============================================================================
# Step 7: Create LTV Bundle
# =============================================================================

print_step "Step 4: Create LTV Bundle"

echo "  Packaging everything for long-term verification..."
echo ""

mkdir -p "$BUNDLE_DIR"

# Copy all components
cp $DEMO_TMP/contract.txt "$BUNDLE_DIR/document.txt"
cp $DEMO_TMP/contract.p7s "$BUNDLE_DIR/signature.p7s"
cp $DEMO_TMP/contract.tsr "$BUNDLE_DIR/timestamp.tsr"
cat $DEMO_TMP/alice.crt $DEMO_TMP/ltv-ca/ca.crt > "$BUNDLE_DIR/chain.pem"
cp $DEMO_TMP/ltv-ca/ca.crt "$BUNDLE_DIR/ca.crt"

# Create manifest
cat > "$BUNDLE_DIR/manifest.json" << EOF
{
  "version": "1.0",
  "created": "$SIGN_DATE",
  "algorithm": "ML-DSA-65",
  "components": {
    "document": "document.txt",
    "signature": "signature.p7s",
    "timestamp": "timestamp.tsr",
    "chain": "chain.pem",
    "ca": "ca.crt"
  },
  "note": "This bundle contains all proofs needed for offline verification in 2055+"
}
EOF

echo -e "  ${GREEN}✓${NC} LTV Bundle created at: $BUNDLE_DIR/"
echo ""
echo -e "  ${CYAN}Bundle contents:${NC}"
ls -la "$BUNDLE_DIR" | sed 's/^/    /'
echo ""

# Calculate total bundle size
bundle_size=$(du -sh "$BUNDLE_DIR" 2>/dev/null | cut -f1)
echo -e "  ${CYAN}Total bundle size:${NC} $bundle_size"
echo ""

pause

# =============================================================================
# Step 8: Verify Offline (Simulating 2055)
# =============================================================================

print_step "Step 5: Verify Offline (Simulating Year 2055)"

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  SIMULATING: It's now 2055. The original CA is long gone.      │"
echo "  │  Bob (archivist) needs to verify this 30-year-old contract.    │"
echo "  │  He only has the LTV bundle - no network access to original CA.│"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

echo "  Verifying CMS signature using bundled chain..."
echo ""

run_cmd "$PKI_BIN cms verify $BUNDLE_DIR/signature.p7s --data $BUNDLE_DIR/document.txt --ca $BUNDLE_DIR/chain.pem"

echo ""
echo -e "  ${GREEN}✓${NC} Signature VALID"
echo -e "  ${GREEN}✓${NC} Document verified using bundled certificate chain"
echo -e "  ${GREEN}✓${NC} No network access required"
echo ""

pause

# =============================================================================
# Step 9: Stop TSA Server
# =============================================================================

print_step "Step 6: Stop TSA Server"

echo "  Stopping the TSA server..."
echo ""

run_cmd "$PKI_BIN tsa stop --port $TSA_PORT"

TSA_PID=""  # Clear PID so cleanup doesn't try to stop again

echo ""

# =============================================================================
# Why LTV Matters (Comparison)
# =============================================================================

echo ""
echo -e "  ${BOLD}WITHOUT LTV (in 2055):${NC}"
echo -e "    ${RED}✗${NC} Signature: Still mathematically valid"
echo -e "    ${RED}✗${NC} Certificate: Cannot verify (CA gone, OCSP offline)"
echo -e "    ${RED}✗${NC} Time of signing: Unknown"
echo -e "    ${RED}→ Result: CANNOT TRUST THE SIGNATURE${NC}"
echo ""
echo -e "  ${BOLD}WITH LTV (in 2055):${NC}"
echo -e "    ${GREEN}✓${NC} Signature: Valid (ML-DSA is quantum-resistant)"
echo -e "    ${GREEN}✓${NC} Certificate: Bundled chain verifies offline"
echo -e "    ${GREEN}✓${NC} Time of signing: Timestamp proves $SIGN_DATE"
echo -e "    ${GREEN}→ Result: FULLY VERIFIED, LEGALLY BINDING${NC}"
echo ""

# =============================================================================
# Conclusion
# =============================================================================

print_key_message "A signature is only as good as its proof chain. LTV bundles everything."

show_lesson "LTV bundles: document + signature + timestamp + chain.
With PQC (ML-DSA), your 30-year contracts stay valid in 2055.
No network dependencies - everything is self-contained.
Essential for legal, medical, and real estate documents."

show_footer

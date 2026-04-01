#!/bin/bash
# =============================================================================
#  QUICK START: Classical vs Post-Quantum
#
#  Create both ECDSA and ML-DSA CAs, issue certificates, compare sizes.
#
#  Key Message: Same workflow, different sizes.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# =============================================================================
# Demo Setup
# =============================================================================

setup_demo "Quick Start"

CLASSIC_CA="$DEMO_TMP/classic-ca"
PQC_CA="$DEMO_TMP/pqc-ca"
PROFILES="$SCRIPT_DIR/profiles"

# =============================================================================
# Introduction
# =============================================================================

echo -e "${BOLD}SCENARIO:${NC}"
echo "  \"I want to issue post-quantum certificates."
echo "   Does it change my PKI workflow?\""
echo ""

init_steps 5

echo -e "${BOLD}WHAT WE'LL DO:${NC}"
echo "  1. Create a classical Root CA (ECDSA P-384)"
echo "  2. Issue a TLS certificate (ECDSA P-384)"
echo "  3. Create a post-quantum Root CA (ML-DSA-65)"
echo "  4. Issue a TLS certificate (ML-DSA-65)"
echo "  5. Compare sizes"
echo ""

echo -e "${DIM}A profile defines: algorithm + validity + X.509 extensions${NC}"
echo ""

pause "Press Enter to start..."

# =============================================================================
# Step 1: Create Classical CA
# =============================================================================

step "Create Classical Root CA" \
     "ECDSA P-384, 20 years validity, CA extensions"

run_cmd "$PKI_BIN ca init --profile $PROFILES/classic-root-ca.yaml --var cn='Classic Root CA' --ca-dir $CLASSIC_CA"

show_files "$CLASSIC_CA"

pause

# =============================================================================
# Step 2: Issue Classical TLS Certificate
# =============================================================================

step "Issue Classical TLS Certificate" \
     "ECDSA P-384, TLS Server extensions (EKU, SAN)"

run_cmd "$PKI_BIN csr gen --algorithm ecdsa-p384 --keyout $DEMO_TMP/classic-server.key --cn classic.example.com --out $DEMO_TMP/classic-server.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $CLASSIC_CA --profile $PROFILES/classic-tls-server.yaml --csr $DEMO_TMP/classic-server.csr --out $DEMO_TMP/classic-server.crt"

echo ""
echo -e "  ${GREEN}Certificate issued.${NC}"
echo ""
echo -e "  ${DIM}File sizes:${NC}"
ls -lh "$DEMO_TMP/classic-server.crt" "$DEMO_TMP/classic-server.key" | awk '{print "    " $5 "  " $9}'

pause

# =============================================================================
# Step 3: Create Post-Quantum CA
# =============================================================================

step "Create Post-Quantum Root CA" \
     "ML-DSA-65 (FIPS 204), 20 years, CA extensions"

run_cmd "$PKI_BIN ca init --profile $PROFILES/pqc-root-ca.yaml --var cn='PQ Root CA' --ca-dir $PQC_CA"

show_files "$PQC_CA"

pause

# =============================================================================
# Step 4: Issue Post-Quantum TLS Certificate
# =============================================================================

step "Issue Post-Quantum TLS Certificate" \
     "ML-DSA-65 (FIPS 204), TLS Server extensions"

run_cmd "$PKI_BIN csr gen --algorithm ml-dsa-65 --keyout $DEMO_TMP/pq-server.key --cn pq.example.com --out $DEMO_TMP/pq-server.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $PQC_CA --profile $PROFILES/pqc-tls-server.yaml --csr $DEMO_TMP/pq-server.csr --out $DEMO_TMP/pq-server.crt"

echo ""
echo -e "  ${GREEN}Certificate issued.${NC}"
echo ""
echo -e "  ${DIM}File sizes:${NC}"
ls -lh "$DEMO_TMP/pq-server.crt" "$DEMO_TMP/pq-server.key" | awk '{print "    " $5 "  " $9}'

pause

# =============================================================================
# Step 5: Comparison
# =============================================================================

step "Size Comparison" \
     "Same workflow, different sizes."

# Get sizes (CA files are in versions/v1/ with algorithm-specific names)
CLASSIC_CA_CERT_SIZE=$(cert_size "$CLASSIC_CA/versions/v1/certs/ca.ecdsa-p384.crt")
CLASSIC_CA_KEY_SIZE=$(key_size "$CLASSIC_CA/versions/v1/keys/ca.ecdsa-p384.key")
CLASSIC_CERT_SIZE=$(cert_size "$DEMO_TMP/classic-server.crt")
CLASSIC_KEY_SIZE=$(key_size "$DEMO_TMP/classic-server.key")

PQC_CA_CERT_SIZE=$(cert_size "$PQC_CA/versions/v1/certs/ca.ml-dsa-65.crt")
PQC_CA_KEY_SIZE=$(key_size "$PQC_CA/versions/v1/keys/ca.ml-dsa-65.key")
PQC_CERT_SIZE=$(cert_size "$DEMO_TMP/pq-server.crt")
PQC_KEY_SIZE=$(key_size "$DEMO_TMP/pq-server.key")

print_comparison_header

echo -e "${BOLD}CA Certificate${NC}"
print_comparison_row "  Cert size" "$CLASSIC_CA_CERT_SIZE" "$PQC_CA_CERT_SIZE" " B"
print_comparison_row "  Key size" "$CLASSIC_CA_KEY_SIZE" "$PQC_CA_KEY_SIZE" " B"

echo ""
echo -e "${BOLD}TLS Server Certificate${NC}"
print_comparison_row "  Cert size" "$CLASSIC_CERT_SIZE" "$PQC_CERT_SIZE" " B"
print_comparison_row "  Key size" "$CLASSIC_KEY_SIZE" "$PQC_KEY_SIZE" " B"

# =============================================================================
# Conclusion
# =============================================================================

echo ""
show_lesson "The PKI doesn't change. Only the algorithm changes.
Your workflow stays exactly the same: ca init → issue → done."

echo -e "${DIM}Explore artifacts: $DEMO_TMP${NC}"
echo ""

show_footer

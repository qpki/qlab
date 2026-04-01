#!/bin/bash
# =============================================================================
#  Lab-07: Timestamping - Trust Now, Verify Forever
#
#  Post-quantum timestamping with ML-DSA
#  Prove when documents existed with unforgeable timestamps
#
#  Key Message: Timestamps prove when documents existed.
#               PQC ensures those proofs remain valid for decades.
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

setup_demo "PQC Timestamping"

PROFILES="$SCRIPT_DIR/profiles"

# =============================================================================
# Introduction
# =============================================================================

echo -e "${BOLD}SCENARIO:${NC}"
echo "  \"I need to prove when a document existed."
echo "   How do I create quantum-resistant timestamps?\""
echo ""

echo -e "${BOLD}WHAT WE'LL DO:${NC}"
echo "  1.  Create a TSA CA (ML-DSA-65)"
echo "  1b. Issue a TSA certificate"
echo "  2.  Start an RFC 3161 timestamp server"
echo "  3.  Create a document"
echo "  3b. Request a timestamp (via HTTP)"
echo "  3c. Verify the timestamp (VALID)"
echo "  4.  Tamper document"
echo "  4b. Verify again (INVALID)"
echo "  5.  Stop TSA server"
echo ""

echo -e "${DIM}RFC 3161 timestamps are the industry standard for proof of existence.${NC}"
echo ""

pause "Press Enter to start..."

# =============================================================================
# Step 1: Create TSA CA
# =============================================================================

print_step "Step 1: Create TSA CA"

echo "  A Timestamp Authority (TSA) issues cryptographic proofs of time."
echo ""

run_cmd "$PKI_BIN ca init --profile $PROFILES/pqc-ca.yaml --var cn=\"TSA Root CA\" --ca-dir $DEMO_TMP/tsa-ca"

# Export CA certificate for verification
$PKI_BIN ca export --ca-dir $DEMO_TMP/tsa-ca --out $DEMO_TMP/tsa-ca/ca.crt

echo ""

pause

# =============================================================================
# Step 2: Issue TSA Certificate
# =============================================================================

print_step "Step 1b: Issue TSA Certificate"

echo "  Generate an ML-DSA-65 key pair and issue TSA certificate."
echo "  The certificate has Extended Key Usage: timeStamping."
echo ""

run_cmd "$PKI_BIN csr gen --algorithm ml-dsa-65 --keyout $DEMO_TMP/tsa.key --cn \"PQC Timestamp Authority\" --out $DEMO_TMP/tsa.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $DEMO_TMP/tsa-ca --profile $PROFILES/pqc-tsa.yaml --csr $DEMO_TMP/tsa.csr --out $DEMO_TMP/tsa.crt"

echo ""

if [[ -f "$DEMO_TMP/tsa.crt" ]]; then
    cert_size=$(wc -c < "$DEMO_TMP/tsa.crt" | tr -d ' ')
    echo -e "  ${CYAN}TSA certificate size:${NC} $cert_size bytes"
fi

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
# Step 4: Create Document
# =============================================================================

print_step "Step 3: Create Document"

echo "  Creating a test contract..."
echo ""

cat > $DEMO_TMP/document.txt << 'EOF'
CONTRACT OF SALE

Date: December 22, 2024
Parties: Alice (Seller), Bob (Buyer)
Amount: 100,000 EUR

This contract represents a binding agreement between
the parties listed above for the sale of property.

Signed electronically.
EOF

echo -e "  ${CYAN}Document content:${NC}"
cat $DEMO_TMP/document.txt | sed 's/^/    /'
echo ""

pause

# =============================================================================
# Step 5: Request Timestamp (via HTTP)
# =============================================================================

print_step "Step 3b: Request Timestamp (via HTTP)"

echo "  Creating timestamp request and sending to TSA server..."
echo ""

run_cmd "$PKI_BIN tsa request --data $DEMO_TMP/document.txt --out $DEMO_TMP/request.tsq"

echo ""

echo -e "  ${DIM}$ curl -s -X POST -H \"Content-Type: application/timestamp-query\" --data-binary @$DEMO_TMP/request.tsq http://localhost:$TSA_PORT/ -o $DEMO_TMP/document.tsr${NC}"
echo ""

curl -s -X POST \
    -H "Content-Type: application/timestamp-query" \
    --data-binary @$DEMO_TMP/request.tsq \
    "http://localhost:$TSA_PORT/" \
    -o $DEMO_TMP/document.tsr

if [[ -f "$DEMO_TMP/document.tsr" ]]; then
    tsr_size=$(wc -c < "$DEMO_TMP/document.tsr" | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} Timestamp token received"
    echo -e "  ${CYAN}Token size:${NC} $tsr_size bytes"
    echo -e "  ${DIM}(ML-DSA-65 signature is ~3,309 bytes)${NC}"
else
    echo -e "  ${RED}✗${NC} Failed to get timestamp"
    exit 1
fi

echo ""

pause

# =============================================================================
# Step 6: Verify Timestamp (VALID)
# =============================================================================

print_step "Step 3c: Verify Timestamp (VALID)"

echo "  Verifying that the document hasn't been modified"
echo "  and the timestamp is valid..."
echo ""

run_cmd "$PKI_BIN tsa verify $DEMO_TMP/document.tsr --data $DEMO_TMP/document.txt --ca $DEMO_TMP/tsa-ca/ca.crt"

echo ""

echo -e "  ${GREEN}✓${NC} Document hash: $(shasum -a 256 $DEMO_TMP/document.txt | cut -d' ' -f1 | head -c 16)..."
echo -e "  ${GREEN}✓${NC} Timestamp contains proof of existence"
echo ""

pause

# =============================================================================
# Step 7: Tamper and Verify Again (INVALID)
# =============================================================================

print_step "Step 4: Tamper Document"

echo "  Simulating document tampering (fraud attempt)..."
echo ""

run_cmd "echo 'FRAUDULENT MODIFICATION' >> $DEMO_TMP/document.txt"

echo ""

pause

# =============================================================================
# Step 4b: Verify Timestamp Again (INVALID)
# =============================================================================

print_step "Step 4b: Verify Timestamp (INVALID)"

echo -e "  ${RED}Simulating fraudulent modification...${NC}"
echo ""

echo "FRAUDULENT AMENDMENT: Amount changed to 1,000,000 EUR" >> $DEMO_TMP/document.txt

echo -e "  ${DIM}$ echo \"FRAUDULENT AMENDMENT\" >> $DEMO_TMP/document.txt${NC}"
echo ""

echo "  Verifying the modified document..."
echo ""

echo -e "  ${DIM}$ qpki tsa verify $DEMO_TMP/document.tsr --data $DEMO_TMP/document.txt --ca $DEMO_TMP/tsa-ca/ca.crt${NC}"
echo ""

if $PKI_BIN tsa verify $DEMO_TMP/document.tsr --data $DEMO_TMP/document.txt --ca $DEMO_TMP/tsa-ca/ca.crt > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Timestamp valid"
else
    echo -e "  ${RED}✗${NC} Timestamp verification FAILED!"
    echo -e "  ${RED}✗${NC} Document has been modified after timestamping"
fi

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  TIMESTAMP VERIFICATION COMPARISON                             │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo -e "  │  BEFORE tampering  →  ${GREEN}VALID${NC}   (timestamp confirmed)          │"
echo -e "  │  AFTER tampering   →  ${RED}INVALID${NC} (modification detected)        │"
echo "  │                                                                 │"
echo "  │  The timestamp proves the document existed at a specific time!  │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

pause

# =============================================================================
# Step 8: Stop TSA Server
# =============================================================================

print_step "Step 5: Stop TSA Server"

echo "  Stopping the TSA server..."
echo ""

run_cmd "$PKI_BIN tsa stop --port $TSA_PORT"

TSA_PID=""  # Clear PID so cleanup doesn't try to stop again

echo ""

# =============================================================================
# Conclusion
# =============================================================================

print_key_message "Timestamps prove when documents existed. PQC ensures those proofs remain valid for decades."

show_lesson "ML-DSA timestamps remain unforgeable even by quantum computers.
Timestamps are the longest-lived cryptographic proofs (30+ years).
RFC 3161 is the industry standard for timestamping.
Legal, patent, and compliance use cases require PQC now."

show_footer

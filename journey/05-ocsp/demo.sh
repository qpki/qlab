#!/bin/bash
# =============================================================================
#  Lab-05: OCSP - Real-Time Certificate Verification
#
#  Real-time certificate status checking with OCSP
#  Query certificate status and see immediate revocation effects
#
#  Key Message: Real-time certificate verification with OCSP works exactly
#               the same with PQC. Same HTTP protocol, same tools.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

setup_demo "OCSP Verification"

PROFILES="$SCRIPT_DIR/profiles"

OCSP_PORT=8888
OCSP_PID=""

# Cleanup function for background OCSP responder
cleanup() {
    if [[ -n "$OCSP_PID" ]]; then
        kill $OCSP_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# =============================================================================
# Introduction
# =============================================================================

echo -e "${BOLD}SCENARIO:${NC}"
echo "  \"I need real-time certificate status, not stale CRLs."
echo "   Does OCSP work with post-quantum certificates?\""
echo ""

echo -e "${BOLD}WHAT WE'LL DO:${NC}"
echo "  1.  Create a PQC CA"
echo "  1b. Issue OCSP responder certificate"
echo "  2.  Start OCSP responder"
echo "  2b. Issue TLS certificate"
echo "  3.  Query certificate status (GOOD)"
echo "  3b. Verify OCSP response (VALID)"
echo "  4.  Revoke the certificate"
echo "  4b. Query again (REVOKED)"
echo "  4c. Verify OCSP response (REVOKED)"
echo "  5.  Stop OCSP responder"
echo ""

echo -e "${DIM}OCSP provides immediate revocation status - no waiting for CRL refresh.${NC}"
echo ""

pause "Press Enter to start..."

# =============================================================================
# Step 1: Create CA
# =============================================================================

print_step "Step 1: Create CA"

echo "  First, we create a PQC CA."
echo ""

run_cmd "$PKI_BIN ca init --profile $PROFILES/pqc-ca.yaml --var cn=\"PQC CA\" --ca-dir $DEMO_TMP/pqc-ca"

# Export CA certificate for OCSP request (issuerKeyHash requires CA public key)
$PKI_BIN ca export --ca-dir $DEMO_TMP/pqc-ca --out $DEMO_TMP/pqc-ca/ca.crt

echo ""

pause

# =============================================================================
# Step 2: Issue OCSP Responder Certificate
# =============================================================================

print_step "Step 1b: Issue OCSP Responder Certificate"

echo "  Generate OCSP responder key and issue certificate."
echo "  Best practice: CA key stays offline, responder has delegated certificate."
echo ""

run_cmd "$PKI_BIN csr gen --algorithm ml-dsa-65 --keyout $DEMO_TMP/ocsp-responder.key --cn \"OCSP Responder\" --out $DEMO_TMP/ocsp-responder.csr"

echo ""

run_cmd "$PKI_BIN cert issue --ca-dir $DEMO_TMP/pqc-ca --profile $PROFILES/pqc-ocsp-responder.yaml --csr $DEMO_TMP/ocsp-responder.csr --out $DEMO_TMP/ocsp-responder.crt"

echo ""

pause

# =============================================================================
# Step 3: Start OCSP Responder
# =============================================================================

print_step "Step 2: Start OCSP Responder"

echo "  The OCSP responder is an HTTP service that answers status queries."
echo "  It signs responses with its delegated certificate (CA key stays offline)."
echo ""

echo -e "  ${DIM}$ qpki ocsp serve --port $OCSP_PORT --ca-dir $DEMO_TMP/pqc-ca --cert $DEMO_TMP/ocsp-responder.crt --key $DEMO_TMP/ocsp-responder.key &${NC}"
echo ""

$PKI_BIN ocsp serve --port $OCSP_PORT --ca-dir $DEMO_TMP/pqc-ca \
    --cert $DEMO_TMP/ocsp-responder.crt \
    --key $DEMO_TMP/ocsp-responder.key > /dev/null 2>&1 &
OCSP_PID=$!

sleep 2

if kill -0 $OCSP_PID 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} OCSP Responder started (PID: $OCSP_PID)"
    echo -e "  ${CYAN}URL: http://localhost:$OCSP_PORT/${NC}"
else
    echo -e "  ${RED}✗${NC} Failed to start OCSP responder"
    exit 1
fi

echo ""

pause

# =============================================================================
# Step 4: Issue TLS Certificate
# =============================================================================

print_step "Step 2b: Issue TLS Certificate"

echo "  Generate TLS server key and issue certificate to verify."
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
# Step 5: Query Certificate Status
# =============================================================================

print_step "Step 3: Query Certificate Status (GOOD)"

echo "  Let's query the OCSP responder for our server certificate status..."
echo ""

# Generate OCSP request
run_cmd "$PKI_BIN ocsp request --issuer $DEMO_TMP/pqc-ca/ca.crt --cert $DEMO_TMP/server.crt --out $DEMO_TMP/request.ocsp"

echo ""
echo "  Send request to OCSP responder via HTTP POST..."
echo ""

run_cmd "curl -s -X POST -H \"Content-Type: application/ocsp-request\" --data-binary @$DEMO_TMP/request.ocsp http://localhost:$OCSP_PORT/ -o $DEMO_TMP/response.ocsp"

echo ""
echo "  Inspect the response..."
echo ""

if [[ -f "$DEMO_TMP/response.ocsp" ]] && [[ -s "$DEMO_TMP/response.ocsp" ]]; then
    run_cmd "$PKI_BIN ocsp info $DEMO_TMP/response.ocsp"
fi
echo ""

pause

# =============================================================================
# Step 3b: Verify OCSP Response (VALID)
# =============================================================================

print_step "Step 3b: Verify OCSP Response (VALID)"

echo "  Cryptographically verify the OCSP response signature..."
echo ""

run_cmd "$PKI_BIN ocsp verify $DEMO_TMP/response.ocsp --ca $DEMO_TMP/pqc-ca/ca.crt --cert $DEMO_TMP/server.crt"

echo ""

pause

# =============================================================================
# Step 4: Revoke Certificate
# =============================================================================

print_step "Step 4: Revoke Certificate"

echo -e "  ${RED}Simulating key compromise...${NC}"
echo ""

run_cmd "$PKI_BIN cert revoke $SERIAL --ca-dir $DEMO_TMP/pqc-ca --reason keyCompromise"

echo ""
echo -e "  ${GREEN}✓${NC} Certificate revoked"
echo ""

pause

# =============================================================================
# Step 7: Query Again (REVOKED)
# =============================================================================

print_step "Step 4b: Query Again (REVOKED)"

echo "  Query again - status should change immediately!"
echo ""

echo "  Send request to OCSP responder via HTTP POST..."
echo ""

run_cmd "curl -s -X POST -H \"Content-Type: application/ocsp-request\" --data-binary @$DEMO_TMP/request.ocsp http://localhost:$OCSP_PORT/ -o $DEMO_TMP/response2.ocsp"

echo ""
echo "  Inspect the response..."
echo ""

if [[ -f "$DEMO_TMP/response2.ocsp" ]] && [[ -s "$DEMO_TMP/response2.ocsp" ]]; then
    run_cmd "$PKI_BIN ocsp info $DEMO_TMP/response2.ocsp"
fi
echo ""

pause

# =============================================================================
# Step 4c: Verify OCSP Response (REVOKED)
# =============================================================================

print_step "Step 4c: Verify OCSP Response (REVOKED)"

echo "  Verify the response signature and check certificate status..."
echo ""

run_cmd "$PKI_BIN ocsp verify $DEMO_TMP/response2.ocsp --ca $DEMO_TMP/pqc-ca/ca.crt --cert $DEMO_TMP/server.crt"

echo ""
echo -e "  ${GREEN}✓${NC} Response signature is valid — the responder is authentic"
echo -e "  ${RED}✗${NC} Certificate status: ${RED}REVOKED${NC} — as expected after key compromise"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  OCSP STATUS COMPARISON                                        │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo -e "  │  BEFORE revocation  →  ${GREEN}GOOD${NC}                                    │"
echo -e "  │  AFTER revocation   →  ${RED}REVOKED${NC}                                 │"
echo "  │                                                                 │"
echo "  │  The status change is IMMEDIATE - no waiting for CRL refresh!  │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

pause

# =============================================================================
# Step 8: Stop OCSP Responder
# =============================================================================

print_step "Step 5: Stop OCSP Responder"

echo "  Stopping the OCSP responder..."
echo ""

run_cmd "$PKI_BIN ocsp stop --port $OCSP_PORT"

OCSP_PID=""  # Clear PID so cleanup doesn't try to stop again

echo ""

# =============================================================================
# Conclusion
# =============================================================================

print_key_message "Real-time certificate verification with OCSP works exactly the same with PQC."

show_lesson "OCSP uses same HTTP protocol with PQC.
Revocation changes are immediate - no CRL staleness.
Delegated responders keep CA keys offline.
PQC responses are larger (~3.5KB) but acceptable."

show_footer

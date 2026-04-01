#!/bin/bash
# =============================================================================
#  Lab-10: Crypto-Agility - Migrate Without Breaking
#
#  Demonstrate CA rotation and trust bundle migration:
#  Phase 1: Classic (ECDSA) → Phase 2: Hybrid → Phase 3: Full PQC
#
#  Key Message: Crypto-agility is the ability to change algorithms
#               without breaking your system. Use trust bundles.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

setup_demo "PQC Crypto-Agility"

# =============================================================================
# Introduction
# =============================================================================

echo -e "${BOLD}SCENARIO:${NC}"
echo "  \"I need to migrate from ECDSA to PQC without breaking clients."
echo "   How do I rotate CA algorithms safely?\""
echo ""

echo -e "${BOLD}WHAT WE'LL DO:${NC}"
echo "  1.  Create Migration CA (ECDSA)"
echo "  1b. Issue ECDSA server certificate (v1)"
echo "  2.  Rotate to hybrid (ECDSA + ML-DSA)"
echo "  2b. Issue hybrid server certificate (v2)"
echo "  3.  Rotate to full PQC (ML-DSA)"
echo "  3b. Issue PQC server certificate (v3)"
echo "  4.  Create trust stores"
echo "  5.  Verify certificates against trust stores"
echo "  6.  Simulate rollback"
echo ""

echo -e "${DIM}Crypto-agility = change algorithms without breaking clients.${NC}"
echo ""

pause "Press Enter to start..."

# =============================================================================
# Understanding Crypto-Agility
# =============================================================================

print_step "What is Crypto-Agility?"

echo "  Crypto-agility is the ability of a system to:"
echo ""
echo "    1. CHANGE algorithms without redesigning architecture"
echo "    2. SUPPORT multiple algorithms during transition"
echo "    3. ROLLBACK quickly if problems occur"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  THE 3-PHASE MIGRATION STRATEGY                                │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │                                                                 │"
echo "  │  PHASE 1: CLASSIC (today)                                      │"
echo "  │    → ECDSA certificates                                        │"
echo "  │    → Status quo, inventory your systems                        │"
echo "  │                                                                 │"
echo "  │  PHASE 2: HYBRID (transition)                                  │"
echo "  │    → ECDSA + ML-DSA in same certificate                        │"
echo "  │    → Legacy clients use ECDSA, modern use both                 │"
echo "  │    → 100% compatibility                                        │"
echo "  │                                                                 │"
echo "  │  PHASE 3: FULL PQC (when ready)                                │"
echo "  │    → ML-DSA only                                               │"
echo "  │    → After ALL clients migrated                                │"
echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  KEY CONCEPT: CA VERSIONING                                    │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │                                                                 │"
echo "  │  Migration CA                                                   │"
echo "  │  ├── v1 (ECDSA)     ──► archived                               │"
echo "  │  ├── v2 (Hybrid)    ──► archived                               │"
echo "  │  └── v3 (ML-DSA)    ──► active                                 │"
echo "  │                                                                 │"
echo "  │  Trust Bundle = v1 + v2 + v3 (published during transition)     │"
echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

pause

# =============================================================================
# Step 1: Create Migration CA (ECDSA)
# =============================================================================

print_step "Step 1: Create Migration CA (ECDSA)"

echo "  Creating the Migration CA with ECDSA (current state)..."
echo "  This represents the starting point of our migration journey."
echo ""

run_cmd "$PKI_BIN ca init --profile $SCRIPT_DIR/profiles/classic-ca.yaml --var cn=\"Migration CA\" --ca-dir $DEMO_TMP/ca"

# Create credentials directory
mkdir -p $DEMO_TMP/credentials

echo ""

# Show certificate info
if [[ -f "$DEMO_TMP/ca/ca.crt" ]]; then
    cert_size=$(wc -c < "$DEMO_TMP/ca/ca.crt" | tr -d ' ')
    echo -e "  ${CYAN}Certificate size:${NC} $cert_size bytes"
    echo -e "  ${DIM}(ECDSA P-256 public key: ~91 bytes)${NC}"
fi

echo ""

pause

# =============================================================================
# Step 2: Issue ECDSA Server Certificate (v1)
# =============================================================================

print_step "Step 1b: Issue ECDSA Server Certificate (v1)"

echo "  Issuing a server certificate with ECDSA..."
echo "  This v1 certificate will be used to test backward compatibility."
echo ""

run_cmd "$PKI_BIN credential enroll --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --profile $SCRIPT_DIR/profiles/classic-tls-server.yaml --var cn=server.example.com"

# Capture the credential ID from the output (skip header and separator lines)
CRED_V1=$($PKI_BIN credential list --cred-dir $DEMO_TMP/credentials 2>/dev/null | grep -v "^ID" | grep -v "^--" | head -1 | awk '{print $1}')

if [[ -n "$CRED_V1" ]]; then
    echo ""
    echo -e "  ${CYAN}Credential ID:${NC} $CRED_V1"
    run_cmd "$PKI_BIN credential export $CRED_V1 --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --out $DEMO_TMP/server-v1.pem"
fi

echo ""

pause

# =============================================================================
# Step 3: Rotate to Hybrid CA (Phase 2)
# =============================================================================

print_step "Step 2: Rotate to Hybrid CA (ECDSA + ML-DSA)"

echo "  Rotating the CA to hybrid mode (Catalyst)..."
echo "  The old ECDSA version becomes archived, new hybrid version is active."
echo ""

run_cmd "$PKI_BIN ca rotate --ca-dir $DEMO_TMP/ca --profile $SCRIPT_DIR/profiles/hybrid-ca.yaml"

echo ""
echo "  Activating the new hybrid version..."
echo ""

run_cmd "$PKI_BIN ca activate --ca-dir $DEMO_TMP/ca --version v2"

echo ""
echo "  Checking CA versions:"
echo ""

run_cmd "$PKI_BIN ca versions --ca-dir $DEMO_TMP/ca"

echo ""

if [[ -f "$DEMO_TMP/ca/ca.crt" ]]; then
    cert_size=$(wc -c < "$DEMO_TMP/ca/ca.crt" | tr -d ' ')
    echo -e "  ${CYAN}New certificate size:${NC} $cert_size bytes"
    echo -e "  ${DIM}(Contains BOTH ECDSA and ML-DSA-65 signatures)${NC}"
fi

echo ""

pause

# =============================================================================
# Step 2b: Issue Hybrid Server Certificate (v2)
# =============================================================================

print_step "Step 2b: Issue Hybrid Server Certificate (v2)"

echo "  Issuing a server certificate with the hybrid CA..."
echo ""

run_cmd "$PKI_BIN credential enroll --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --profile $SCRIPT_DIR/profiles/hybrid-tls-server.yaml --var cn=server.example.com"

# Get the new credential ID (skip header, separator, and first credential)
CRED_V2=$($PKI_BIN credential list --cred-dir $DEMO_TMP/credentials 2>/dev/null | grep -v "^ID" | grep -v "^--" | grep -v "$CRED_V1" | head -1 | awk '{print $1}')

if [[ -n "$CRED_V2" ]]; then
    echo ""
    echo -e "  ${CYAN}Credential ID:${NC} $CRED_V2"
    run_cmd "$PKI_BIN credential export $CRED_V2 --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --out $DEMO_TMP/server-v2.pem"
fi

echo ""

pause

# =============================================================================
# Step 3: Rotate to Full PQC CA (Phase 3)
# =============================================================================

print_step "Step 3: Rotate to Full PQC CA (ML-DSA)"

echo "  Rotating the CA to full post-quantum..."
echo "  ML-DSA-65 only (no classical fallback)."
echo ""

run_cmd "$PKI_BIN ca rotate --ca-dir $DEMO_TMP/ca --profile $SCRIPT_DIR/profiles/pqc-ca.yaml"

echo ""
echo "  Activating the new PQC version..."
echo ""

run_cmd "$PKI_BIN ca activate --ca-dir $DEMO_TMP/ca --version v3"

echo ""
echo "  Checking CA versions:"
echo ""

run_cmd "$PKI_BIN ca versions --ca-dir $DEMO_TMP/ca"

echo ""

if [[ -f "$DEMO_TMP/ca/ca.crt" ]]; then
    cert_size=$(wc -c < "$DEMO_TMP/ca/ca.crt" | tr -d ' ')
    echo -e "  ${CYAN}New certificate size:${NC} $cert_size bytes"
    echo -e "  ${DIM}(ML-DSA-65 public key: ~1,952 bytes)${NC}"
fi

echo ""

pause

# =============================================================================
# Step 5: Issue PQC Server Certificate (v3)
# =============================================================================

print_step "Step 3b: Issue PQC Server Certificate (v3)"

echo "  Issuing a server certificate with ML-DSA..."
echo ""

run_cmd "$PKI_BIN credential enroll --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --profile $SCRIPT_DIR/profiles/pqc-tls-server.yaml --var cn=server.example.com"

# Get the new credential ID (skip header, separator, and first credential)
CRED_V3=$($PKI_BIN credential list --cred-dir $DEMO_TMP/credentials 2>/dev/null | grep -v "^ID" | grep -v "^--" | grep -v "$CRED_V1" | grep -v "$CRED_V2" | head -1 | awk '{print $1}')

if [[ -n "$CRED_V3" ]]; then
    echo ""
    echo -e "  ${CYAN}Credential ID:${NC} $CRED_V3"
    run_cmd "$PKI_BIN credential export $CRED_V3 --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --out $DEMO_TMP/server-v3.pem"
fi

echo ""

pause

# =============================================================================
# Step 6: Create Trust Stores
# =============================================================================

print_step "Step 4: Create Trust Stores"

echo "  Creating trust stores for different client scenarios..."
echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  TRUST STORE STRATEGY                                          │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │                                                                 │"
echo "  │  Clients Legacy ── trust-legacy.pem ──► CA v1 ──► Cert v1      │"
echo "  │  Clients Modern ── trust-modern.pem ──► CA v3 ──► Cert v3      │"
echo "  │                                                                 │"
echo "  │  Transition :                                                   │"
echo "  │  Clients ── trust-transition.pem ──► CA v1 / v2 / v3           │"
echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

echo "  Trust store for legacy clients (v1 only):"
run_cmd "$PKI_BIN ca export --ca-dir $DEMO_TMP/ca --version v1 --out $DEMO_TMP/trust-legacy.pem"

echo ""
echo "  Trust store for modern clients (v3 only):"
run_cmd "$PKI_BIN ca export --ca-dir $DEMO_TMP/ca --version v3 --out $DEMO_TMP/trust-modern.pem"

echo ""
echo "  Trust store for transition (all versions):"
run_cmd "$PKI_BIN ca export --ca-dir $DEMO_TMP/ca --all --out $DEMO_TMP/trust-transition.pem"

echo ""

if [[ -f "$DEMO_TMP/trust-transition.pem" ]]; then
    bundle_size=$(wc -c < "$DEMO_TMP/trust-transition.pem" | tr -d ' ')
    echo -e "  ${CYAN}Transition bundle size:${NC} $bundle_size bytes (contains all CA versions)"
fi

echo ""
echo -e "  ${YELLOW}Note:${NC} The trust bundle is a temporary migration artifact."
echo "        It should be removed once all clients have migrated to PQC."
echo ""

pause

# =============================================================================
# Step 7: Verify Certificates Against Trust Stores
# =============================================================================

print_step "Step 5: Verify Certificates Against Trust Stores"

echo "  Testing that certificates validate correctly with their trust stores:"
echo ""

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  INTEROPERABILITY MATRIX                                       │"
echo "  ├─────────────────────────────────────────────────────────────────┤"

# Test 1: Legacy cert with legacy trust
echo -n "  │  v1 cert + trust-legacy.pem   │  "
if $PKI_BIN cert verify $DEMO_TMP/server-v1.pem --ca $DEMO_TMP/trust-legacy.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}                          │"
else
    echo -e "${RED}✗ FAIL${NC}                        │"
fi

# Test 2: Hybrid cert with transition trust
echo -n "  │  v2 cert + trust-transition   │  "
if $PKI_BIN cert verify $DEMO_TMP/server-v2.pem --ca $DEMO_TMP/trust-transition.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}                          │"
else
    echo -e "${RED}✗ FAIL${NC}                        │"
fi

# Test 3: PQC cert with modern trust
echo -n "  │  v3 cert + trust-modern.pem   │  "
if $PKI_BIN cert verify $DEMO_TMP/server-v3.pem --ca $DEMO_TMP/trust-modern.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}                          │"
else
    echo -e "${RED}✗ FAIL${NC}                        │"
fi

# Test 4: Legacy cert with transition trust
echo -n "  │  v1 cert + trust-transition   │  "
if $PKI_BIN cert verify $DEMO_TMP/server-v1.pem --ca $DEMO_TMP/trust-transition.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}                          │"
else
    echo -e "${RED}✗ FAIL${NC}                        │"
fi

# Test 5: PQC cert with transition trust
echo -n "  │  v3 cert + trust-transition   │  "
if $PKI_BIN cert verify $DEMO_TMP/server-v3.pem --ca $DEMO_TMP/trust-transition.pem > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}                          │"
else
    echo -e "${RED}✗ FAIL${NC}                        │"
fi

echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

echo "  Key insight:"
echo "    - Old certificates (v1) remain valid after CA rotation"
echo "    - Transition bundle supports ALL certificate versions"
echo "    - Clients choose which trust store to use based on their capabilities"
echo ""

pause

# =============================================================================
# Step 8: Simulate Rollback
# =============================================================================

print_step "Step 6: Simulate Rollback"

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │  SCENARIO: Compatibility issue detected on legacy appliances   │"
echo "  │  ACTION: Rollback to Hybrid CA (v2) to restore service         │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  Crypto-agility means you can go BACK if needed."
echo "  Let's reactivate the Hybrid CA (v2)..."
echo ""

run_cmd "$PKI_BIN ca activate --ca-dir $DEMO_TMP/ca --version v2"

echo ""
echo "  Checking CA versions after rollback:"
echo ""

run_cmd "$PKI_BIN ca versions --ca-dir $DEMO_TMP/ca"

echo ""
echo -e "  ${YELLOW}v2 (Hybrid) is now active again!${NC}"
echo ""
echo "  This is critical for safe migrations:"
echo "    - If PQC causes issues, rollback to Hybrid"
echo "    - If Hybrid causes issues, rollback to Classic"
echo "    - All existing certificates remain valid"
echo ""

pause

# =============================================================================
# Conclusion: Inspect Certificates
# =============================================================================

print_step "Inspect Certificates"

echo "  Examining the certificates we created:"
echo ""

echo "  === v1 Certificate (ECDSA) ==="
run_cmd "$PKI_BIN inspect $DEMO_TMP/server-v1.pem"

echo ""
echo "  === v2 Certificate (Hybrid) ==="
run_cmd "$PKI_BIN inspect $DEMO_TMP/server-v2.pem"

echo ""
echo "  === v3 Certificate (ML-DSA) ==="
run_cmd "$PKI_BIN inspect $DEMO_TMP/server-v3.pem"

echo ""
echo "  === All Credentials ==="
run_cmd "$PKI_BIN credential list --cred-dir $DEMO_TMP/credentials"

echo ""

# =============================================================================
# Conclusion
# =============================================================================

print_key_message "Crypto-agility = change algorithms WITHOUT breaking clients"

show_lesson "1. Use CA ROTATION to evolve cryptographic algorithms
2. Publish TRUST BUNDLES during migration (v1+v2+v3)
3. Old certificates REMAIN VALID after CA rotation
4. ROLLBACK is always possible - activate older versions
5. Never do \"big bang\" migration - it's too risky"

show_footer

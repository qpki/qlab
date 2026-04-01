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
echo "  1b. Issue ECDSA server certificate"
echo "  2.  Rotate CA to hybrid (ECDSA + ML-DSA)"
echo "  2b. Rotate credential to hybrid"
echo "  3.  Rotate CA to full PQC (ML-DSA)"
echo "  3b. Rotate credential to PQC"
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

print_step "Step 1b: Issue ECDSA Server Certificate"

echo "  Issuing a server certificate with ECDSA..."
echo "  This initial certificate will be rotated as the CA migrates."
echo ""

run_cmd "$PKI_BIN credential enroll --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --profile $SCRIPT_DIR/profiles/classic-tls-server.yaml --var cn=server.example.com"

# Capture the credential ID from the output (skip header and separator lines)
CRED_ID=$($PKI_BIN credential list --cred-dir $DEMO_TMP/credentials 2>/dev/null | grep -v "^ID" | grep -v "^--" | head -1 | awk '{print $1}')

if [[ -n "$CRED_ID" ]]; then
    echo ""
    echo -e "  ${CYAN}Credential ID:${NC} $CRED_ID"
    run_cmd "$PKI_BIN credential export $CRED_ID --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --out $DEMO_TMP/server-v1.pem"
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

print_step "Step 2b: Rotate Credential to Hybrid"

echo "  Same server, new algorithm — zero downtime migration."
echo "  The credential is rotated, not recreated."
echo ""

run_cmd "$PKI_BIN credential rotate $CRED_ID --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --profile $SCRIPT_DIR/profiles/hybrid-tls-server.yaml"

echo ""
run_cmd "$PKI_BIN credential export $CRED_ID --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --out $DEMO_TMP/server-v2.pem"

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

print_step "Step 3b: Rotate Credential to PQC"

echo "  Final migration step — full post-quantum."
echo "  Same credential, now with ML-DSA-65."
echo ""

run_cmd "$PKI_BIN credential rotate $CRED_ID --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --profile $SCRIPT_DIR/profiles/pqc-tls-server.yaml"

echo ""
run_cmd "$PKI_BIN credential export $CRED_ID --ca-dir $DEMO_TMP/ca --cred-dir $DEMO_TMP/credentials --out $DEMO_TMP/server-v3.pem"

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

echo "  ┌──────────────────────────────────────────────────────────────────┐"
echo "  │  INTEROPERABILITY MATRIX                                        │"
echo "  ├───────────────┬─────────────────────┬──────────────────────────┤"
echo "  │  Certificate  │  Trust Store        │  Result                  │"
echo "  ├───────────────┼─────────────────────┼──────────────────────────┤"

# v1 tests
for trust in trust-legacy trust-transition trust-modern; do
    echo -n "  │  v1 (ECDSA)   │  ${trust}$(printf '%*s' $((20 - ${#trust})) '')│  "
    if $PKI_BIN cert verify $DEMO_TMP/server-v1.pem --ca $DEMO_TMP/${trust}.pem > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}                     │"
    else
        echo -e "${RED}✗ FAIL${NC}                   │"
    fi
done

# v2 tests
for trust in trust-legacy trust-transition trust-modern; do
    echo -n "  │  v2 (Hybrid)  │  ${trust}$(printf '%*s' $((20 - ${#trust})) '')│  "
    if $PKI_BIN cert verify $DEMO_TMP/server-v2.pem --ca $DEMO_TMP/${trust}.pem > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}                     │"
    else
        echo -e "${RED}✗ FAIL${NC}                   │"
    fi
done

# v3 tests
for trust in trust-legacy trust-transition trust-modern; do
    echo -n "  │  v3 (ML-DSA)  │  ${trust}$(printf '%*s' $((20 - ${#trust})) '')│  "
    if $PKI_BIN cert verify $DEMO_TMP/server-v3.pem --ca $DEMO_TMP/${trust}.pem > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}                     │"
    else
        echo -e "${RED}✗ FAIL${NC}                   │"
    fi
done

echo "  └───────────────┴─────────────────────┴──────────────────────────┘"
echo ""

echo "  Key insight:"
echo "    - Each cert only works with trust stores that contain its CA version"
echo "    - Transition bundle supports ALL certificate versions"
echo "    - FAIL is expected: it proves trust isolation works correctly"
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

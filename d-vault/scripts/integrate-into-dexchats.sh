#!/usr/bin/env bash
# ============================================================================
# integrate-into-dexchats.sh
# ============================================================================
# Run this from the dexchats monorepo root AFTER running deploy.sh to deploy
# the Vault contract on Acki Nacki mainnet.
#
# Usage:
#   bash /path/to/dpass/scripts/integrate-into-dexchats.sh <dexchats-root>
#
# Example:
#   bash ../dpass/scripts/integrate-into-dexchats.sh .
# ============================================================================
set -euo pipefail

DVAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEXCHATS_DIR="${1:?Usage: $0 <dexchats-root>}"

echo "=== Integrating d-vault into DexChats ==="
echo "  d-vault dir: $DVAULT_DIR"
echo "  dexchats dir: $DEXCHATS_DIR"

# 1. Dart package → packages/
echo "[1/4] Copying Dart package..."
mkdir -p "$DEXCHATS_DIR/packages/d-vault"
cp -r "$DVAULT_DIR/packages/d-vault/"* "$DEXCHATS_DIR/packages/d-vault/"

# 2. Go service → services/
echo "[2/4] Copying Go service..."
mkdir -p "$DEXCHATS_DIR/services/d-vault"
cp -r "$DVAULT_DIR/services/d-vault/"* "$DEXCHATS_DIR/services/d-vault/"

# 3. Contract → contracts/vault/
echo "[3/4] Copying contract..."
mkdir -p "$DEXCHATS_DIR/contracts/vault"
cp "$DVAULT_DIR/contracts/Vault.sol" "$DEXCHATS_DIR/contracts/vault/"
cp "$DVAULT_DIR/contracts/Vault.abi.json" "$DEXCHATS_DIR/contracts/vault/"

# 4. Deploy script → scripts/
echo "[4/4] Copying deploy script..."
cp "$DVAULT_DIR/scripts/deploy.sh" "$DEXCHATS_DIR/scripts/deploy-vault.sh"

echo ""
echo "=== Done ==="
echo ""
echo "Next steps in DexChats:"
echo "  1. cd $DEXCHATS_DIR/packages/d-vault && dart pub get"
echo "  2. cd $DEXCHATS_DIR/services/d-vault && go mod tidy"
echo "  3. Wire DVaultService into Identity Kernel in apps/mobile/"
echo ""
echo "See AGENTS.md for architecture details."

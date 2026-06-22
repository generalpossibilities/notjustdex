#!/usr/bin/env bash
set -euo pipefail

NETWORK="${1:-shellnet}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONTRACTS_DIR="$PROJECT_DIR/contracts"

echo "=== d-vault Deploy :: Network: $NETWORK ==="

case "$NETWORK" in
  shellnet)
    TVM_URL="shellnet.ackinacki.org"
    ;;
  mainnet)
    TVM_URL="mainnet.ackinacki.org"
    ;;
  *)
    echo "Unknown network: $NETWORK (use shellnet or mainnet)"
    exit 1
    ;;
esac

echo "Compiling Vault.sol..."
sold \
  --tvm-version gosh \
  --output-dir "$CONTRACTS_DIR" \
  "$CONTRACTS_DIR/Vault.sol"

KEYS_FILE="$CONTRACTS_DIR/vault.keys.json"
if [ ! -f "$KEYS_FILE" ]; then
  echo "Generating key pair..."
  tvm-cli config --url "$TVM_URL"
  tvm-cli genaddr \
    "$CONTRACTS_DIR/Vault.tvc" \
    --abi "$CONTRACTS_DIR/Vault.abi.json" \
    --genkey "$KEYS_FILE" \
    --save
else
  echo "Using existing keys: $KEYS_FILE"
  tvm-cli genaddr \
    "$CONTRACTS_DIR/Vault.tvc" \
    --abi "$CONTRACTS_DIR/Vault.abi.json" \
    --setkey "$KEYS_FILE" \
    --save
fi

ADDR=$(cat "$CONTRACTS_DIR/Vault.addr" 2>/dev/null || echo "")
if [ -z "$ADDR" ]; then
  echo "ERROR: Contract address not found."
  exit 1
fi
echo "Contract address: $ADDR"

echo ""
echo "=== Deploy Instructions ==="
echo ""
echo "1. Fund the address with 10+ SHELL using your Multisig wallet:"
echo "   tvm-cli call <MULTISIG> sendTransaction '{\"dest\":\"$ADDR\",\"value\":10000000000,\"bounce\":false,\"flags\":1,\"payload\":\"\"}' --abi <ABI> --sign <KEYS>"
echo ""
echo "2. Deploy the contract:"
echo "   tvm-cli deploy \\"
echo "     --abi \"$CONTRACTS_DIR/Vault.abi.json\" \\"
echo "     --sign \"$KEYS_FILE\" \\"
echo "     \"$CONTRACTS_DIR/Vault.tvc\" \\"
echo '     '"'"'{"owner":"<OWNER_WALLET_ADDRESS_HEX>","value":10000000000}'"'"'"
echo ""
echo "Done."

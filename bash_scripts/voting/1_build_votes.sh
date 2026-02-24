#!/bin/bash

# --- CONFIG ---
DATE_STAMP=$(date +%d%m%y)
TX_BODY="${DATE_STAMP}-tx.body"
PAYMENT_ADDR=$(cat /path/to/payment.addr)
BASE_URL="https://raw.githubusercontent.com/username/path/to/rationale/folder/"

DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

# 1. AUTO-FETCH "CLEAN" UTXO (ADA Only)
if [ "$DRY_RUN" = false ]; then
    echo "Searching for a clean UTXO..."
    UTXO=$(cardano-cli query utxo --address "$PAYMENT_ADDR" --mainnet --out-file /dev/stdout | \
    jq -r 'to_entries | map(select(.value.value | length == 1 and has("lovelace"))) | sort_by(.value.value.lovelace) | last | .key')

    if [ "$UTXO" == "null" ] || [ -z "$UTXO" ]; then
        echo "ERROR: No pure ADA UTXOs found."; exit 1
    fi
    echo "Using UTXO: $UTXO"
else
    echo "--- DRY RUN MODE ---"
    UTXO="DUMMY_UTXO_FOR_TESTING#0"
fi

# 2. PROCESS MANIFEST
VOTE_FILES_CMD=""
HAS_DREP=0; HAS_SPO=0

while read -r ID ROLE VOTE METADATA_FILE; do
    [[ -z "$ID" || "$ID" == "#"* ]] && continue
    [[ "$ROLE" == "drep" ]] && HAS_DREP=1
    [[ "$ROLE" == "spo" ]] && HAS_SPO=1

    # Auto-Hash Metadata
    HASH=$(b2sum -l 256 "metadata/$METADATA_FILE" | awk '{print $1}')
    URL="${BASE_URL}/${METADATA_FILE}"
    OUT_VOTE="vote_${ID//[:#]/_}_${ROLE}.vote"

    [[ "$ROLE" == "drep" ]] && FLAG="--drep-verification-key-file /path/to/drep.vkey" || FLAG="--stake-pool-verification-key-file $NODE_HOME/path/to/node.vkey"

    cardano-cli conway governance vote create \
        --$(echo "$VOTE" | tr '[:upper:]' '[:lower:]') \
        --governance-action-tx-id "${ID%#*}" \
        --governance-action-index "${ID#*#}" \
        $FLAG \
        --anchor-url "$URL" \
        --anchor-data-hash "$HASH" \
        --out-file "$OUT_VOTE"

    VOTE_FILES_CMD+="--vote-file $OUT_VOTE "
done < governance.list

# 3. BUILD (Only if not Dry Run)
if [ "$DRY_RUN" = false ]; then
    WITNESS_COUNT=$(( 1 + HAS_DREP + HAS_SPO ))
    cardano-cli conway transaction build \
        --mainnet \
        --tx-in "$UTXO" \
        $VOTE_FILES_CMD \
        --change-address "$PAYMENT_ADDR" \
        --witness-override $WITNESS_COUNT \
        --out-file "$TX_BODY"

    echo "Success! Build created at $TX_BODY"
    cardano-cli debug transaction view --tx-body-file "$TX_BODY"
else
    echo "Dry run complete. Hashes and .vote files are valid."
fi

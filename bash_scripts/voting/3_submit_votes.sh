#!/bin/bash
DATE_STAMP=$(date +%d%m%y)
TX_BODY="${DATE_STAMP}-tx.body"

# Build witness arguments based on what was brought back
WITNESS_ARGS="--witness-file payment.witness"
[ -f drep.witness ] && WITNESS_ARGS+=" --witness-file drep.witness"
[ -f spo.witness ] && WITNESS_ARGS+=" --witness-file spo.witness"

# Assemble & Submit
cardano-cli conway transaction assemble --tx-body-file "$TX_BODY" $WITNESS_ARGS --out-file "${DATE_STAMP}-tx.signed"
cardano-cli conway transaction submit --tx-file "${DATE_STAMP}-tx.signed" --mainnet 2>&1 | tee tx_hash.txt # Outputs copy of tx hash to .txt file

# Archive everything
mkdir -p archive/"$DATE_STAMP"
mv *.vote *.witness *.body *.signed *.txt archive/"$DATE_STAMP"/

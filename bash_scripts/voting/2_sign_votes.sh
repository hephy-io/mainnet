# For use on COLD device

read -p "Enter Date (DDMMYY) from file: " DATE
TX_BODY="${DATE}-tx.body"
WITNESS_FILES=()

echo "Which witnesses do you require?"
echo "1) DRep"
echo "2) SPO"
echo "3) Both"
read -p "Selection [1-3]: " WITNESS_CHOICE

# Validate input - Exit with error if not 1, 2, or 3
if [[ ! "$WITNESS_CHOICE" =~ ^[1-3]$ ]]; then
    echo "Invalid selection. Exiting."
    exit 1
fi

# --- 1. Mandatory Payment Witness (Always generated) ---
cardano-cli conway transaction witness \
    --tx-body-file "$TX_BODY" \
    --signing-key-file "/path/to/ayment.skey" \
    --out-file payment.witness
WITNESS_FILES+=("--witness-file payment.witness")

# --- 2. Optional Witnesses based on input ---
case $WITNESS_CHOICE in
    1)
        cardano-cli conway transaction witness --tx-body-file "$TX_BODY" --signing-key-file /path/to/drep.skey --out-file drep.witness
        WITNESS_FILES+=("--witness-file drep.witness")
        ;;
    2)
        cardano-cli conway transaction witness --tx-body-file "$TX_BODY" --signing-key-file /path/to/node.skey --out-file spo.witness
        WITNESS_FILES+=("--witness-file spo.witness")
        ;;
    3)
        cardano-cli conway transaction witness --tx-body-file "$TX_BODY" --signing-key-file /path/to/drep.skey --out-file drep.witness
        cardano-cli conway transaction witness --tx-body-file "$TX_BODY" --signing-key-file /path/to/node.skey --out-file spo.witness
        WITNESS_FILES+=("--witness-file drep.witness" "--witness-file spo.witness")
        ;;
esac

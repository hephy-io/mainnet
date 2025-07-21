GOV_ACTION_ID="<insert id here>"

cardano-cli conway query gov-state --mainnet | \
jq -r --arg govActionId ${GOV_ACTION_ID} \
'.proposals | to_entries[] | select(.value.actionId.txId == $govActionId and .value.actionId.govActionIx == 1) | .value'

GOV_ACTION_ID="<enter id here>"

cardano-cli conway query gov-state --mainnet | \
jq -r --arg govActionId ${GOV_ACTION_ID} '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value'

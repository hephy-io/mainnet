cardano-cli conway query gov-state --mainnet | \
jq -r --arg govActionId "8ad3d454f3496a35cb0d07b0fd32f687f66338b7d60e787fc0a22939e5d8833e" \
'.proposals | to_entries[] | select(.value.actionId.txId == $govActionId and .value.actionId.govActionIx == 1) | .value'

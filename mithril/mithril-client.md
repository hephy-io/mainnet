# Bootstrap a Cardano Node using Mithril Client

## Pre-requisites
### Install Rust

`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

### Update Rust

`rustup update`

### Install dependencies

`sudo apt install build-essential m4 libssl-dev jq`

## Building from source (about 5 mins)
```
git clone https://github.com/input-output-hk/mithril.git
git checkout latest
cd mithril/mithril-client-cli
make test
make build
```

## Downloading the pre-built binary
```
curl --proto '=https' --tlsv1.2 -sSf
https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh
| sh -s -- -c mithril-client -d latest -p YOUR_PATH
```

### Move executable 

`sudo mv mithril-client /usr/local/bin/`

## Create a download-db script
```
sudo bash -c 'cat > /path/to/script/download-db.sh << EOF
#!/bin/bash
CARDANO_NETWORK=mainnet
AGGREGATOR_ENDPOINT=https://aggregator.release-mainnet.api.mithril.network/aggregator
GENESIS_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-infra/configuration/release-mainnet/genesis.vkey)
ANCILLARY_VERIFICATION_KEY=$(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-infra/configuration/release-mainnet/ancillary.vkey)
SNAPSHOT_DIGEST=latest

./mithril-client cardano-db download --include-ancillary $SNAPSHOT_DIGEST --download-dir /path/to/node/db
EOF'
```

### Run the script

`./download-db.sh`

## Start cardano-node
`sudo systemctl start cardano-node`

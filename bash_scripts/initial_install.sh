#!/bin/bash

# Initial install of cardano-node and mithril for fast bootstraping for Ubuntu 22.04+
# Mithril snapshot download dependent upon internet connection speeds

# Exit on error
set -e

# --- 1. USER INTERACTION & RAM CHECK ---
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "================================================================="
echo "   CARDANO INITIAL SETUP | SYSTEM RAM: ${TOTAL_RAM}GB"
echo "================================================================="
echo "Choose your installation mode:"
echo "1) EXPRESS (Recommended) - Downloads pre-built binaries (5-10 mins)"
echo "2) BUILD - Compiles from source (Requires 16GB+ RAM / 1-2 hours)"
read -p "Enter choice [1 or 2]: " choice

case $choice in
    1) MODE="EXPRESS" ;;
    2)
        if [ "$TOTAL_RAM" -lt 12 ]; then
            echo "WARNING: Building from source with less than 16GB RAM is highly likely to fail."
            read -p "Continue anyway? (y/n): " confirm
            [[ $confirm != [yY] ]] && exit 1
        fi
        MODE="BUILD"
        ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

# --- 2. CONFIGURATION ---
GHC_VERSION="9.6.6"
CABAL_VERSION="3.10.3.0"
BLST_VERSION="v0.3.14"
NODE_HOME="$HOME/cardano-node"
SRC_DIR="$HOME/src"

# Mithril Network Config
AGGREGATOR_ENDPOINT="https://aggregator.release-mainnet.api.mithril.network/aggregator"
GENESIS_VKEY_URL="https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/genesis.vkey"
ANCILLARY_VKEY_URL="https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/ancillary.vkey"

# --- 3. SYSTEM DEPENDENCIES ---
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev \
libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq curl wget \
libncursesw5 libtool autoconf libsqlite3-dev liblmdb-dev m4 ufw fail2ban

# --- 4. TOOLCHAINS (Always installed for future-proofing) ---
echo "--- Installing Toolchains (Haskell & Rust) ---"
export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
export BOOTSTRAP_HASKELL_GHC_VERSION=$GHC_VERSION
export BOOTSTRAP_HASKELL_CABAL_VERSION=$CABAL_VERSION
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"

if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

mkdir -p "$SRC_DIR"

# --- 5. CRYPTO LIBRARIES (Always built locally for compatibility) ---
echo "--- Building Crypto Libraries ---"
cd "$SRC_DIR"
# Libsodium
git clone https://github.com/intersectmbo/libsodium 2>/dev/null || cd libsodium
cd "$SRC_DIR/libsodium" && git checkout dbb48cc
./autogen.sh && ./configure && make && sudo make install

# secp256k1
cd "$SRC_DIR"
git clone https://github.com/bitcoin-core/secp256k1 2>/dev/null || cd secp256k1
cd "$SRC_DIR/secp256k1" && git checkout ac83be33
./autogen.sh && ./configure --enable-module-schnorrsig --enable-experimental && make && sudo make install

# blst
cd "$SRC_DIR"
git clone https://github.com/supranational/blst 2>/dev/null || cd blst
cd "$SRC_DIR/blst" && git fetch --all --tags && git checkout $BLST_VERSION
./build.sh
cat << EOF > libblst.pc
prefix=/usr/local
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: libblst
Description: Multilingual BLS12-381 signature library
Version: 0.3.14
Libs: -L\${libdir} -lblst
Cflags: -I\${includedir}
EOF
sudo cp libblst.a /usr/local/lib
sudo cp bindings/blst.h bindings/blst_aux.h /usr/local/include
sudo cp libblst.pc /usr/local/lib/pkgconfig/
sudo ldconfig

# --- 6. DYNAMIC VERSIONING ---

LATEST_TAG=$(curl -s https://api.github.com/repos/intersectmbo/cardano-node/releases/latest | jq -r .tag_name)
MITHRIL_TAG=$(curl -s https://api.github.com/repos/input-output-hk/mithril/releases/latest | jq -r .tag_name)

echo "--- Installing Node $LATEST_TAG | Mithril $MITHRIL_TAG ($MODE mode) ---"

# --- 7. BINARY INSTALLATION ---
if [ "$MODE" == "EXPRESS" ]; then
    echo "--- Downloading Pre-built Binaries ---"
    cd "$SRC_DIR"
    NODE_URL="https://github.com/intersectmbo/cardano-node/releases/download/$LATEST_TAG/cardano-node-$LATEST_TAG-linux.tar.gz"
    wget -N "$NODE_URL"
    tar -xf "cardano-node-$LATEST_TAG-linux.tar.gz"
    sudo cp ./bin/cardano-node ./bin/cardano-cli /usr/local/bin/

    MITHRIL_URL="https://github.com/input-output-hk/mithril/releases/download/$MITHRIL_TAG/mithril-$MITHRIL_TAG-linux-x64.tar.gz"
    wget -N "$MITHRIL_URL"
    tar -xf "mithril-$MITHRIL_TAG-linux-x64.tar.gz"
    sudo cp mithril-client /usr/local/bin/
else
    echo "--- Building Binaries from Source ---"
    cd "$SRC_DIR"
    git clone https://github.com/intersectmbo/cardano-node.git 2>/dev/null || cd cardano-node
    cd "$SRC_DIR/cardano-node" && git fetch --all --tags && git checkout "$LATEST_TAG"
    cabal update
    cabal build all --extra-lib-dirs=/usr/local/lib --extra-include-dirs=/usr/local/include
    sudo cp $(find dist-newstyle -name cardano-node -type f) /usr/local/bin/
    sudo cp $(find dist-newstyle -name cardano-cli -type f) /usr/local/bin/

    cd "$SRC_DIR"
    git clone https://github.com/input-output-hk/mithril.git 2>/dev/null || cd mithril
    cd "$SRC_DIR/mithril" && git fetch --all --tags && git checkout "$MITHRIL_TAG"
    cd mithril-client-cli && cargo build --release
    sudo cp ../target/release/mithril-client /usr/local/bin/
fi

# --- 8. CONFIGURATION & P2P ---
echo "--- Setting up Configs ---"
mkdir -p "$NODE_HOME/config" "$NODE_HOME/db" "$NODE_HOME/sockets" "$NODE_HOME/scripts"
cd "$NODE_HOME/config"
BASE_URL="https://book.world.dev.cardano.org/environments/mainnet"
for file in config.json topology.json byron-genesis.json shelley-genesis.json alonzo-genesis.json conway-genesis.json checkpoints.json; do
    wget -N "$BASE_URL/$file"
done
jq '.EnableP2P = true | .hasPrometheus = ["0.0.0.0", 12798]' config.json > config.json.tmp && mv config.json.tmp config.json

# --- 9. MITHRIL BOOTSTRAP ---
echo "--- Fast-Syncing with Mithril ---"
export AGGREGATOR_ENDPOINT=$AGGREGATOR_ENDPOINT
export GENESIS_VERIFICATION_KEY=$(curl -sSf $GENESIS_VKEY_URL)
export ANCILLARY_VERIFICATION_KEY=$(curl -sSf $ANCILLARY_VKEY_URL)

rm -rf "$NODE_HOME/db"/*
mithril-client cardano-db download latest --download-dir "$NODE_HOME" --include-ancillary

# --- 10. SECURITY & SYSTEMD ---
sudo ufw allow 6000/tcp
echo "y" | sudo ufw enable

cat << EOF > "$NODE_HOME/scripts/start-cardano-node.sh"
#!/bin/bash
cardano-node run \\
  --topology $NODE_HOME/config/topology.json \\
  --database-path $NODE_HOME/db \\
  --socket-path $NODE_HOME/sockets/node.socket \\
  --host-addr 0.0.0.0 \\
  --port 6000 \\
  --config $NODE_HOME/config/config.json \\
EOF
chmod +x "$NODE_HOME/scripts/start-cardano-node.sh"

sudo bash -c "cat << EOF > /etc/systemd/system/cardano-node.service
[Unit]
Description=Cardano Node
After=network.target
[Service]
User=$USER
WorkingDirectory=$NODE_HOME
ExecStart=/bin/bash $NODE_HOME/scripts/start-cardano-node.sh
Restart=always
RestartSec=5
LimitNOFILE=32768
[Install]
WantedBy=multi-user.target
EOF"

# --- 11. FINALIZING ---
{
  echo "export NODE_HOME=$NODE_HOME"
  echo "export CARDANO_NODE_SOCKET_PATH=$NODE_HOME/sockets/node.socket"
  echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH'
  echo 'export CARDANO_NETWORK=mainnet'
  echo 'export CARDANO_NODE_SOCKET_PATH="$NODE_HOME/sockets/node.socket"'
} >> "$HOME/.bashrc"

sudo systemctl daemon-reload
sudo systemctl enable cardano-node
# rm -rf "$SRC_DIR"

echo "================================================================="
echo "   DONE! Running source ~/.bashrc && launching cardano-node"
echo "================================================================="

# --- 12. AUTO-LAUNCH WITH TMUX ---
echo "--- Launching Node and Environment ---"
source "$HOME/.bashrc"
sudo systemctl start cardano-node

if [ -z "$TMUX" ]; then
    # Create session, tail logs in right pane, keep user active in left pane
    tmux new-session -d -s cardano
    tmux split-window -v 'journalctl -fu cardano-node -ocat'
    tmux select-pane -t 0
    tmux attach-session -t cardano
else
    # If already in tmux, just open a new pane for logs
    tmux split-window -v 'journalctl -fu cardano-node -ocat'
    tmux select-pane -t 0
fi

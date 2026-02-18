# Setup Mithril Signer as an SPO (BP and Relay)

## Pre-requisites
#### Install Rust

`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

#### Update Rust

`rustup update`

#### Install dependencies

`sudo apt install build-essential m4 libssl-dev jq`

## Installation of mithril-signer (BP)
### Building from source (about 5 mins)
```
git clone https://github.com/input-output-hk/mithril.git
cd mithril
git checkout 2603.1
cd mithril/mithril-signer
make test
make build
```

### Downloading the pre-built binary
```
curl --proto '=https' --tlsv1.2 -sSf
https://raw.githubusercontent.com/input-output-hk/mithril/refs/heads/main/mithril-install.sh
| sh -s -- -c mithril-signer -d latest -p YOUR_PATH
```

### Verify the binary

`./mithril-signer -V`

### Create the mithril folder and move the executable
```
sudo mkdir -p /opt/mithril
sudo mv mithril-signer /opt/mithril
```

### Create the mithril environment file 
Named to play nice with gLiveView (official docs use mithril-signer.env)
```
sudo bash -c 'cat > /opt/mithril/mithril.env << EOF
KES_SECRET_KEY_PATH=/path/to/your/kes.skey
OPERATIONAL_CERTIFICATE_PATH=/path/to/your/node.cert
NETWORK=mainnet
AGGREGATOR_ENDPOINT=https://aggregator.release-mainnet.api.mithril.network/aggregator
RUN_INTERVAL=60000
DB_DIRECTORY=/path/to/your/db
CARDANO_NODE_SOCKET_PATH=/path/to/your/node.socket
CARDANO_CLI_PATH=/usr/local/bin/cardano-cli
DATA_STORES_DIRECTORY=/opt/mithril/stores
STORE_RETENTION_LIMIT=5
ERA_READER_ADAPTER_TYPE=cardano-chain
ERA_READER_ADAPTER_PARAMS={"address":"addr1qy72kwgm6kypyc5maw0h8mfagwag8wjnx6emgfnsnhqaml6gx7gg4tzplw9l32nsgclqax7stc4u6c5dn0ctljwscm2sqv0teg","verification_key":"5b31312c3133342c3231352c37362c3134312c3232302c3131312c3135342c36332c3233302c3131342c31322c38372c37342c39342c3137322c3133322c32372c39362c3138362c3132362c3137382c31392c3131342c33302c3234332c36342c3134312c3131302c38332c38362c31395d"}
RELAY_ENDPOINT=SQUID_RELAY_IP:3132
# Optional Metrics Settings
# ENABLE_METRICS_SERVER=true
# METRICS_SERVER_IP=0.0.0.0
# METRICS_SERVER_PORT=9090
EOF'
```

### Installing the service
#### Create the mithril-signer service file
```
sudo bash -c 'cat > /etc/systemd/system/mithril-signer.service << EOF
[Unit]
Description=Mithril signer service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=60
User=cardano
EnvironmentFile=/opt/mithril/mithril.env
ExecStart=/opt/mithril/mithril-signer -vvv

[Install]
WantedBy=multi-user.target
EOF'
```

#### Reload and start the service
```
sudo systemctl daemon-reload
sudo systemctl start mithril-signer
sudo systemctl enable mithril-signer
systemctl status mithril-signer.service
```

# Setup Mithril relay node using Squid (Relay)
## Pre-requisites
If running Ubuntu 22.04 or older, remove any version of Squid installed via the `apt` package manager.
The package manager only installs up to v5.4 of Squid which is not as secure as v6.12 and above, compile newer versions from source.

```
sudo systemctl stop squid
sudo apt remove squid
sudo apt autoremove
```

## Compile Squid from source (version 6.12+)
### Download Squid
```
wget https://www.squid-cache.org/Versions/v6/squid-6.12.tar.gz
tar xzf squid-6.12.tar.gz
cd squid-6.12
```

### Configure Squid
```
./configure \
    --prefix=/opt/squid \
    --localstatedir=${prefix}/var \
    --libexecdir=${prefix}/lib/squid \
    --datadir=${prefix}/share/squid \
    --sysconfdir=/etc/squid \
    --with-default-user=USER \
    --with-logdir=${prefix}/var/log/squid \
    --with-pidfile=${prefix}/var/run/squid.pid
```

### Compile
```
make
sudo make install
```

### Verify installed version

`/opt/squid/sbin/squid -v`

## Configure the Squid proxy
### Make a backup of the original config file

`sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak`

### Prepare the forward proxy configuration file
```
sudo bash -c 'cat > /etc/squid/squid.conf << EOF
# Listening port (port 3132 is recommended)
http_port 3132

# ACL for the internal IP of your block producer node
acl block_producer_internal_ip src **YOUR_BLOCK_PRODUCER_INTERNAL_IP**

# ACL for aggregator endpoint
acl aggregator_domain dstdomain .mithril.network

# ACL for SSL port only
acl SSL_port port 443

# Allowed traffic
http_access allow block_producer_internal_ip aggregator_domain SSL_port

# Do not disclose block producer internal IP
forwarded_for delete

# Turn off via header
via off

# Deny request for original source of a request
follow_x_forwarded_for deny all

# Anonymize request headers
request_header_access Authorization allow all
request_header_access Proxy-Authorization allow all
request_header_access Cache-Control allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Connection allow all
request_header_access All deny all

# Disable cache
cache deny all

# Deny everything else
http_access deny all

EOF'
```

### Create the service file
```
sudo bash -c 'cat > /etc/systemd/system/squid.service << EOF
[Unit]
Description=Squid service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=60
User=squid
Group=squid
ExecStart=/opt/squid/sbin/squid -f /etc/squid/squid.conf -d5
PIDFile=/opt/squid/var/run/squid.pid

[Install]
WantedBy=multi-user.target
EOF'
```

### Reload and start the service
```
sudo systemctl daemon-reload
sudo systemctl start squid
sudo systemctl enable squid
systemctl status squid
```

### Firewall Settings (Squid Relay)

`sudo ufw allow from **YOUR_BLOCK_PRODUCER_INTERNAL_IP** to any port **YOUR_RELAY_LISTENING_PORT** proto tcp`

## Verify Setup
#### Check that the signer is registered
```
wget https://mithril.network/doc/scripts/verify_signer_registration.sh
chmod +x verify_signer_registration.sh
PARTY_ID=**YOUR_POOL_ID** AGGREGATOR_ENDPOINT=**YOUR_AGGREGATOR_ENDPOINT** ./verify_signer_registration.sh
```

#### Check that the signer is contributing
```
wget https://mithril.network/doc/scripts/verify_signer_signature.sh
chmod +x verify_signer_signature.sh
PARTY_ID=**YOUR_POOL_ID** AGGREGATOR_ENDPOINT=**YOUR_AGGREGATOR_ENDPOINT** ./verify_signer_signature.sh
```

# Maintenance
### Restart Signer whenever cardano-node is restarted

`sudo systemctl restart mithril-signer`

### Updating Mithril Signer
#### Update Rust

`rustup update`

#### Update from source (about 5 mins)
```
git clone https://github.com/input-output-hk/mithril.git
git checkout latest
cd mithril/mithril-signer
make test
make build
```

#### Stop mithril-signer, move the new executable to the `/opt/mithril/` folder and restart the signer
```
sudo systemctl stop mithril-signer
sudo mv /opt/mithril/mithril-signer /opt/mithril/mithril-signer-old
sudo cp mithril-signer /opt/mithril/
sudo systemctl start mithril-signer
```

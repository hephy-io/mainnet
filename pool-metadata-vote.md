**How to add a rationale file to your SPO vote:**

When you create the vote file on your cold environment like so:

```
cardano-cli conway governance vote create \
    --yes \
    --governance-action-tx-id "47a0e7a4f9383b1afc2192b23b41824d65ac978d7741aca61fc1fa16833d1111" \
    --governance-action-index "0" \
    --cold-verification-key-file $HOME/cold-keys/node.vkey \
    --out-file 47a0e7a4f9383b1afc2192b23b41824d65ac978d7741aca61fc1fa16833d1111-pool.vote
```

Just add an additional two lines containing the url to your rationale file and its hash like so:

```
cardano-cli conway governance vote create \
    --yes \
    --governance-action-tx-id 47a0e7a4f9383b1afc2192b23b41824d65ac978d7741aca61fc1fa16833d1111 \
    --governance-action-index "0" \
    --cold-verification-key-file $HOME/cold-keys/node.vkey \
    --anchor-url "https://raw.githubusercontent.com/hephy-io/mainnet/refs/heads/main/drep_rationales/GA061-update-committee.jsonld" \
    --anchor-data-hash "7809e04a30e640ac4464c38be846d32ca46f9cab99ed8c58f51b7fd0701f16a7" \
    --out-file 47a0e7a4f9383b1afc2192b23b41824d65ac978d7741aca61fc1fa16833d1111-pool.vote
```

To get the correct hash of your rationale file, download the raw file:

`wget https://raw.githubusercontent.com/hephy-io/mainnet/refs/heads/main/drep_rationales/GA061-update-committee.jsonld`

Calculate the hash:

`b2sum -l 256 GA061-update-committee.jsonld`

Save the output:

`GA061-update-committee.jsonld 7809e04a30e640ac4464c38be846d32ca46f9cab99ed8c58f51b7fd0701f16a7`

Prerequisites: Java 21 installed on client machine, visit https://github.com/IntersectMBO/cc-ballot/blob/main/cli/cc-ballot-cli/README.md

1. Download the latest release `wget https://github.com/IntersectMBO/cc-ballot/releases/download/1.0.1/cc-ballot-cli-all.zip`

2. Unzip the file `unzip cc-ballot-cli-all.zip`

3. Get payload from https://elections.constitution.gov.tools/ (It will look like this).
```
   {
    "action": "cast_vote",
    "slot": "<slot number at vote>", // This needs to be a future slot so use "cardano-cli query tip --mainnet --socket-path /path/to/socket" and add 300 (5 mins)
    "data": {
      "event": "CC-Elections-2025",
      "category": "CATEGORY_E794",
      "proposal": "0ae97786-d17b-4f96-84af-979ff9c0b276",
      "id": "e4cd6467-3ba5-4eb7-8eed-db95f023d5ab",
      "votedAt": "<slot number at vote>", // Add same (slot number + 300) here
      "timestamp": 1749763465,
      "walletId": "<DRep ID>", // Add DRep ID here (cat drep.id)
      "walletType": "CARDANO",
      "network": "MAIN",
      "votes": [] // Election page will insert vote numbers into this array
    }
  }
```

4. Store payload JSON in a payload.json file

5. Sign the payload using Cardano signer (preferably on your cold env!)
```
    cardano-signer sign --cip8 \
        --data payload.json \
        --secret-key drep.skey \
        --address drep.id \
        --json
```
7. Run `java -jar cc-ballot-cli-all.jar cast_vote payload.json "<signature>" "<pubKey>"` // Copy paste the outputs from Cardano Signer here, run inside unzipped cc-ballot-cli folder

8. To verify your vote, edit the payload.json (create as receipt.json if easier) E.g. `cp payload.json receipt.json` then `nano receipt.json`
```
{
    "action": "view_vote_receipt", // Change "cast_vote" to "view_vote_receipt"
    "slot": "<slot number at vote>", // This needs to be a future slot so use "cardano-cli query tip --mainnet --socket-path /path/to/socket" and add 300 (5 mins)
    "data": {
      "event": "CC-Elections-2025",
      "category": "CATEGORY_E794",
      "proposal": "0ae97786-d17b-4f96-84af-979ff9c0b276",
      "id": "e4cd6467-3ba5-4eb7-8eed-db95f023d5ab",
      "votedAt": "<slot number at vote>", // Add same (slot number + 300) here
      "timestamp": 1749763465,
      "walletId": "<DRep ID>", // Add DRep ID here (cat drep.id)
      "walletType": "CARDANO",
      "network": "MAIN",
      "votes": [] // Election page will insert vote numbers into this array
    }
  }
```

9. Re-sign with Cardano Signer
 ```
cardano-signer sign --cip8 \
--data payload.json \ // Or receipt.json if saved as a separate file
--secret-key drep.skey \
--address drep.id \
--json
```

10. Run `java -jar cc-ballot-cli-all.jar view_vote_receipt payload.json "<signature>" "<pubKey>"` // Copy paste the outputs from Cardano Signer here, run inside unzipped cc-ballot-cli folder


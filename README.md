# CoMakery Security Token

## Dev Setup

Install: 

* Node.js
* Yarn package management for Node.js
* MetaMask chrome browser extension. This is your Ethereum Wallet. You will need this for deployment and the demo.
* Ganache (a test blockchain). Launch it. Set your ganache RPC port to `HTTP://0.0.0.0:8545`

**MetaMask Setup:**

* Set your MetaMask wallet to point to your Ganache blockchain at http://localhost:8545
* Create a new account from "import". Paste in the private key from the generated test accounts in your Ganache blockchain test simulator.
* When you reload the Ganache test blockchain you will need to delete the transaction information from previous interactions with the old blockchain test data. To do this go to Account > Settings > Advance > Reset Account.

**Setup this code:**
```
git clone git@github.com:CoMakery/comakery-security-token.git
cd comakery-security-token

yarn install
yarn setup
yarn dev

open http://localhost:8080
```
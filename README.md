# CoMakery Security Token

## Status: Work In Progress

## Overview

The CoMakery Security Token implements the **ERC-20** token standard and the **ERC-1404** security token standard. It attempts to balance simplicity and sufficiency for smart contract tokens that need to comply with Regulatory Authorities. Simplicity is necessary to make the full operations of the contract clear to users of the smart contracts and for reducing the number of smart contract lines that need to be secured (each line of a smart contract is a security liability).

## Disclaimer

This open source software is provided with no warranty. This is not legal advice. CoMakery is not a legal firm and is not your lawyer. Securities are highly regulated across multiple jurisdictions. Issuing a security token incorrectly can result in financial penalties and jail time if you do it wrong. Consult a lawyer and tax advisor. Conduct an independent security audit of the code.

# Primary Issuance

## Initial Security Token Setup

![](docs/plant-uml-diagrams/setup.png)

- Separating Token Treasury From Transfer Approvals

## Issuer Issues the Token To AML / KYC'd Recipients

![](docs/plant-uml-diagrams/basic-issuance.png)

1. Token Lockup Period Based On Jurisdiction
1. Unaccredited (Everyday) Investors Can Acquire a Limited Amount of Tokens

# Transfer Restrictions

![](docs/plant-uml-diagrams/transfer-restrictions.png)

| From | To | Restrict | Enforced By |
|:-|:-|:-|:-|
| Reg D/S/CF | Anyone | Until TimeLock ends | setTimeLock(investorAddress)
| Reg S Group | US Accredited | Not During Flowback Restriction Period | allowGroupTransfer(fromGroupS, toGroupD, afterTime); |
| Reg S Group | Reg S Group | Not Until Shorter Reg S TimeLock Ended | allowGroupTransfer(fromGroupS, toGroupS, afterTime); |
| Stolen Tokens | Anyone | Freeze, Burn, Reissue| freeze(stolenTokenAddress);<br /> burnFrom(address, amount);<br />mint(newOwnerAddress); |
| Issuer | Reg CF with > maximum value of tokens allowed | Forbidden | setMaxBalance() |
| Any Address During Regulatory Freeze| Anyone | Forbidden | pause() |

## Accredited Investors Can Trade With Other Investors In The Same Group (e.g. Reg S)

To allow trading in a group:
* Call `setRestrictions(address, transferGroup, addressTimeLock, maxTokens)` for traders in the group 
* `allowGroupTransfer(fromGroupX, toGroupX, groupTimeLock)` for account addresses associated with groupIDs like Reg S 
* The token holders in the group can trade with each other as long as: 
    * the `addressTimelock` and `groupTimeLock` times have passed; and 
    * the recipient of a token transfer does not exceeded the `maxTokens` in their account address.

## Avoiding Flow Back of Reg S Assets

To allow trading between Foreign Reg S account addresses but forbid flow back to US Reg D account addresses until the end of the Reg D lockup period
* Call `setRestrictions(address, groupIDForRegS, shorterTimeLock, maxTokens)` for Reg S investors
* Call `setRestrictions(address, groupIDForRegD, longerTimeLock, maxTokens)` for Reg D investors
* `allowGroupTransfer(groupIDForRegS, groupIDForRegS, groupTimeLock)` allow Reg S trading 
* The token holders in the group can trade with each other as long as: 
    * the `addressTimelock` and `groupTimeLock` times have passed; and 
    * the recipient of a token transfer does not exceeded the `maxTokens` in their account address.h

## Exchanges Can Register Omnibus Accounts

## Enforcing Maximum Holders Rules

## Transfers Can Be Paused To Comply With Regulatory Action

## Recovery From Blockchain Fork

## Law Enforcement Recovery of Stolen Assets

## Lost Key Token Recovery

# Compatibility With Dividend Distribution and Staking Contracts

Although this code does not implement dividend distribution or staking, it can be used with staking and dividend contracts. Contact noah@comakery.com for further details.

# Dev Setup

Install: 

* Node.js
* Yarn package management for Node.js
* MetaMask chrome browser extension. This is your Ethereum Wallet. You will need this for deployment and the demo.
* Ganache (a test blockchain). Launch it. Set your ganache RPC port to `HTTP://0.0.0.0:8545`

## MetaMask Setup

* Set your MetaMask wallet to point to your Ganache blockchain at http://localhost:8545
* Create a new account from "import". Paste in the private key from the generated test accounts in your Ganache blockchain test simulator.
* When you reload the Ganache test blockchain you will need to delete the transaction information from previous interactions with the old blockchain test data. To do this go to Account > Settings > Advance > Reset Account.

## Setup this code
```
git clone git@github.com:CoMakery/comakery-security-token.git
cd comakery-security-token

yarn install
yarn setup
yarn dev

open http://localhost:8080
```


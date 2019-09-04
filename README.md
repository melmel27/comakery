# Cosecto

## An Open Source Security Token From Your Friends At CoMakery

## Status: Work In Progress

## Overview

Cosecto, is an open source Security Token from CoMakery. Cosecto implements the **ERC-20** token standard and the **ERC-1404** security token standard. It attempts to balance simplicity and sufficiency for smart contract tokens that need to comply with regulatory authorities. 

Simplicity is necessary to make the full operations of the contract clear to users of the smart contracts. Simplicity also reduces the number of smart contract lines that need to be secured (each line of a smart contract is a security liability).

## Disclaimer

This open source software is provided with no warranty. This is not legal advice. CoMakery is not a legal firm and is not your lawyer. Securities are highly regulated across multiple jurisdictions. Issuing a security token incorrectly can result in financial penalties and jail time if you do it wrong. Consult a lawyer and tax advisor. Conduct an independent security audit of the code.

# Primary Issuance

## Initial Security Token Deployment

![](docs/plant-uml-diagrams/setup.png)

1. The Deployer configures the parameters and deploys the smart contracts to a public blockchain. The deployment allows configuration of a separate reserve address and Transfer Administrator address. This allows the reserve security tokens to be stored in cold storage since the treasury reserve address private keys are not needed for everyday use by the Transfer Admin.
2. The Transfer Admin can then provisions a hot wallet address for distributing tokens to investors or other stakeholders. The Transfer Admin uses `setRestrictions(investorAddress, transferGroup, addressTimeLock, maxTokens)` to set address restrictions.
3. The Transfer Admin authorizes the transfer of tokens between account groups with `allowGroupTransfer(fromGroup, toGroup, afterTimestamp)` .
4. The Reserve Admin can then transfer tokens to the Hot Wallet address.
5. The Hot Wallet Admin can then transfer tokens to investors or other stakeholders who are entitled to tokens.


## Setup For Separate Issuer Private Key Management Roles

By default the reserve tokens cannot be transferred to any address. To allow transfers the Transfer Admin must configure transfer rules using both `setRestrictions(account, ...)` and `allowGroupTransfer(...)`.

During the setup process for added security, the Transfer Admin can setup rules that only allow the Reserve Admin to transfer tokens to the hot wallet address first. The Hot Wallet is also restricted to a limited max balance. This enforces transfer approvals for multiple private key holders for token transfers of large size - and a limited loss from any single account with a single transfer. The use of a hot wallet for small balances also makes everyday token administration easier without exposing the issuer's reserve of tokens to the risk of total theft in a single transaction.

The Reserve Account restriction configuration can be accomplished in this manner:
1. Transfer Admin, Reserve Admin and Hot Wallet admin accounts are managed by separate users with separate keys. For example, separate Nano Ledger S hardware wallets.
1. Reserve and Hot Wallet addresses have their own separate transfer groups
    * `unrestrictedAddressTimeLock = 0` this timestamp will always have passed
    * `unrestrictedMaxTokenAmount = 2**256 -1` is the largest number storable this number is available as the `MAX_UNIT()` constant.
    * `setRestrictions(reserveAddress, reserveTransferGroup, unrestrictedAddressTimelock, unrestrictedMaxTokenAmount)`
    * `setRestrictions(reserveAddress, hotWalletTransferGroup, unrestrictedAddressTimeLock, sensibleMaxAmountInHotWallet)`
1. Reserve Address can only transfer to Hot Wallet Groups
    * `allowGroupTransfer(reserveTransferGroup, hotWalletTransferGroup, unrestrictedAddressTimeLock)`
    * `setRestrictions(reserveAddress, hotWalletTransferGroup, unrestrictedAddressTimeLock, sensibleMaxAmountInHotWallet)`
1. Hot Wallet Address can transfer to investor groups like Reg D and Reg S.
    * `allowGroupTransfer(hotWalletTransferGroup, regD_TransferGroup, unrestrictedAddressTimeLock)`
    * `allowGroupTransfer(hotWalletTransferGroup, regS_TransferGroup, unrestrictedAddressTimeLock)`

Then the Hot Wallet Admin can distribute tokens to investors and stakeholders as described below...

## Issuer Issues the Token To AML / KYC'd Recipients

![](docs/plant-uml-diagrams/basic-issuance.png)

1. The Transfer Admin gathers AML/KYC and accreditation information from investors and stakeholders who will receive tokens directly from the issuer (the Primary Issuance).
1. Transfer Admin then configures approved blockchain account addresses for investor and stakholders with `h`. Based on the AML/KYC and accreditation process the investor can provision the account address with a maximum number of tokens; a transfer group designating a regulatory class like "Reg D", "Reg CF" or "Reg S"; and a date that the tokens in the address will be locked until.
1. The tokens can then be transferred to the provisioned addresses.

Note that there are no transfers yet authorized between accounts. By default all transfers are restricted.

1. Token Lockup Period Based On Jurisdiction
1. Unaccredited (Everyday) Investors Can Acquire a Limited Amount of Tokens

# Transfer Restrictions

![](docs/plant-uml-diagrams/transfer-restrictions.png)

The Transfer Admin for the Token Contract can provision account addresses to transfer and receive tokens under certain conditions. This is the process for configuring transfer restrictions and transferring tokens:
1. An Investor sends their Anti Money Laundering and Know Your Customer (AML/KYC) information to the Transfer Admin or to a proxy vetting service to verify this information. The benefit of using a qualified third party provider is to avoid needing to store privately identifiable information.
1. The Transfer Admin calls `setRestrictions(investorAddress, transferGroup, addressTimeLock, maxTokens)` to provision their account. Initially this will be done for the Primary Issuance of tokens to investors where tokens are distributed directly from the issuer to holder accounts.
1. A potential buyer sends their AML/KYC information to the Transfer Admin.
1. The Transfer Admin calls `setRestrictions(buyerAddress, transferGroup, addressTimeLock, maxTokens)` to provision the Buyer account.
1. At this time or before, the Transfer Admin authorizes the transfer of tokens between account groups with `allowGroupTransfer(fromGroup, toGroup, afterTimestamp)` . Note that allowing a transfer from group A to group B does not allow a transfer from group B to group B. This would have to be done separately. An example is that Reg CF unaccredited investors may be allowed to sell to Accredited US investors but not vice versa.

## Overview of Transfer Restriction Enforcement Methods

| From | To | Restrict | Enforced By |
|:-|:-|:-|:-|
| Reg D/S/CF | Anyone | Until TimeLock ends | `setTimeLock(investorAddress)` |
| Reg S Group | US Accredited | Forbidden During Flowback Restriction Period | `allowGroupTransfer(fromGroupS, toGroupD, afterTime)` |
| Reg S Group | Reg S Group | Forbidden Until Shorter Reg S TimeLock Ended | `allowGroupTransfer(fromGroupS, toGroupS, afterTime)` |
| Stolen Tokens | Anyone | Fix With Freeze, Burn, Reissue| `freeze(stolenTokenAddress);`<br /> `burnFrom(address, amount);`<br />`mint(newOwnerAddress);` |
| Issuer | Reg CF with > maximum value of tokens allowed | Forbid transfers increasing token balances above max balance | `setMaxBalance(amount)` |
| Any Address During Regulatory Freeze| Anyone | Forbid all transfers while paused | `pause()` |

## Investors Can Trade With Other Investors In The Same Group (e.g. Reg S)

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

## Enforcing Maximum Holders Rules

By default blockchain addresses cannot receive tokens. To receive tokens the issuer gathers AML/KYC information and then calls `setRestrictions()`. A single user may have multiple addresses. The issuer can track the number of holders offline and stop authorizing holders when the maximum holders amount has been reached.

If you need tracking for max number of holders implemented contact noah@comakery.com

## Exchanges Can Register Omnibus Accounts

Centralized exchanges can register custody addresses using the same method as other users. They contact the Issuer to provision accounts and the Transfer Admin calls `setRestrictions()` for the exchange account.

When customers of the exchange want to withdraw tokens from the exchange account they must withdraw into an account that the Transfer Admin has provisioned for them with `setRestrictions()`.

Talk to a lawyer about when exchange accounts may or may not exceed the maximum number of holders allowed for a token.

## Transfers Can Be Paused To Comply With Regulatory Action

If there is a regulatory issue with the token, all transfers may be paused by calling `pause()`. During normal functioning of the contract, `pause()` should never need to be called.

## Recovery From A Blockchain Fork

Issuers should have a plan for what to do during a blockchain fork. Often security tokens represent a scarce off chain asset and a fork in the blockchain may present ambiguity about who can claim an off chain asset. For example, if 1 token represents 1 ounce of gold, a fork introduces 2 competing claims for 1 ounce of gold. 

In the advent of a blockchain fork, the issuer should do something like the following:
- have a clear way of signaling which branch of the blockchain is valid
- signal which branch is the system of record
- call `pause()` on the invalid fork
- use `burn()` and `mint()` to fix errors that have been agreed to by both parties involved or ruled by a court in the issuers jurisdiction

## Law Enforcement Recovery of Stolen Assets

In the case of stolen assets with sufficient legal reason to be returned to their owner, the issuer can call `freeze()`, `burn()`, and `mint()` to transfer the assets to the appropriate account.

Although this is not in the spirit of a cryptocurrency, it is available as a response to requirements that some regulators impose on blockchain security token projects.

## Lost Key Token Recovery

In the case of lost keys with sufficient legal reason to be returned to their owner, the issuer can call `freeze()`, `burn()`, and `mint()` to transfer the assets to the appropriate account. This opens the issuer up to potential cases of fraud. Handle with care.

Once again, although this is not in the spirit of a cryptocurrency, it is available as a response to requirements that some regulators impose on blockchain security token projects.

# Compatible With Dividend Distribution and Staking Contracts

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


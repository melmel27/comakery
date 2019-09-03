```plantuml
@startuml setup
!include style.iuml
actor "Deployer" as Deployer
participant "Token Contract" as Token
actor "Transfer\nAdmin" as TAdmin
actor "Reserve\nAdmin" as RAdmin
actor "Hot Wallet\nAdmin" as HAdmin

Deployer -> Token: constructor(\nreserveAddress,\ntransferAdminAddress,\nsymbol,\ndecimals,\ntotalSupply,\n...)
TAdmin -> Token: set transfer rules
RAdmin -> Token: transfer tokens to hot wallet
HAdmin -> Token: issue tokens to investors from hot wallet
activate Token
Token -> Token: detectTransferRestriction(from, to, value)
@enduml
```

```plantuml
@startuml basic-issuance
!include style.iuml
actor "Investor" as Investor
actor "Transfer\nAdmin" as TAdmin
participant "Token Contract" as Token
actor "Hot Wallet\nAdmin" as HAdmin

Investor -> TAdmin: send AML/KYC and accreditation info
TAdmin -> Token: setMaxBalance(investorAddress, maxTokens)
TAdmin -> Token: setTimeLock(investorAddress, timeToUnlock)
HAdmin -> Token: transfer(investorAddress, amount)
activate Token
Token -> Token: detectTransferRestriction(from, to, value)
@enduml
```

```plantuml
@startuml p2p-trade
!include style.iuml
actor Buyer
actor "Transfer\nAdmin" as TAdmin
participant "Token Contract" as Token
actor Seller


Buyer -> TAdmin: send AML/KYC and accreditation info
TAdmin -> Token: setMaxBalance(buyerAddress, maxTokens)
TAdmin -> Token: setTimeLock(buyerAddress, timeToUnlock)
TAdmin -> Token: allowTransferFromGroup(sellerAddress, groupNumber)
TAdmin -> Token: allowTransferToGroup(buyerAddress, groupNumber)
Seller -> Token: transfer(buyerAddress, amount)
activate Token
Token -> Token: detectTransferRestriction(from, to, value)
@enduml
```

```plantuml
@startuml restrict-flowback-of-reg-s
!include style.iuml
actor "Transfer\nAdmin" as TAdmin
participant "Token Contract" as Token
actor "US Reg D\nInvestor" as DInvestor
actor "US Reg CF\nInvestor" as CFInvestor
actor "Foreign Reg S\nInvestor" as ForeignInvestor
actor "US Secondary\nMarket Buyer" as USBuyer
actor "Foreign Secondary\nMarket Buyer" as ForeignBuyer

TAdmin -> Token: setMaxBalance(buyerAddress, maxTokens)
TAdmin -> Token: setTimeLock(buyerAddress, timeToUnlock)
TAdmin -> Token: allowTransferFromGroup(sellerAddress, groupNumber)
TAdmin -> Token: allowTransferToGroup(buyerAddress, groupNumber)
activate Token
Token -> Token: detectTransferRestriction(from, to, value)
@enduml
```

```plantuml
@startuml us-lockup-period
!include style.iuml
actor "US Accredited\nSecondary Market Buyer" as Buyer
actor "Transfer\nAdmin" as TAdmin
participant "Token Contract" as Token
actor "US Reg D or CF\nInvestor" as Seller

TAdmin -> Token: allowTransferFromGroup(sellerAddress, groupNumber)
TAdmin -> Token: setTimeLock(sellerAddress, timeToUnlock)

Buyer -> TAdmin: send AML/KYC and accreditation info
TAdmin -> Token: setMaxBalance(buyerAddress, maxTokens)
TAdmin -> Token: allowTransferToGroup(buyerAddress, groupNumber)
TAdmin -> Token: setTimeLock(buyerAddress, timeToUnlock)
activate Token
Seller -> Token: transfer(usAccreditedBuyerAddress,\namount)
Token -> Token: detectTransferRestriction(from, to, value)
@enduml
```
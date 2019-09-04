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
TAdmin -> Token: setRestrictions(hotWalletAddress, issuerTransferGroup, addressTimeLock, maxTokens)
RAdmin -> Token: transfer tokens to hot wallet
TAdmin -> Token: setRestrictions(investorAddress, issuerTransferGroup, addressTimeLock, maxTokens)
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
TAdmin -> Token: setRestrictions(investorAddress, transferGroup, addressTimeLock, maxTokens)\n// Reg D, S or CF
HAdmin -> Token: transfer(investorAddress, amount)
activate Token
Token -> Token: detectTransferRestriction(from, to, value)

@enduml
```

```plantuml
@startuml transfer-restrictions
!include style.iuml
actor Buyer
actor Investor
actor "Transfer\nAdmin" as TAdmin
participant "Token Contract" as Token

Investor -> TAdmin: send AML/KYC and accreditation info
TAdmin -> Token: setRestrictions(buyerAddress, transferGroup, addressTimeLock, maxTokens)


Buyer -> TAdmin: send AML/KYC and accreditation info
TAdmin -> Token: setRestrictions(sellerAddress, transferGroup, addressTimeLock, maxTokens)
TAdmin -> Token: allowGroupTransfer(fromGroup, toGroup, afterTimestamp)

Investor -> Token: transfer(buyerAddress, amount)
activate Token
Token -> Token: detectTransferRestriction(from, to, value)

note left 
    **Transfer** or **Revert** depending on the result code
end note

@enduml
```
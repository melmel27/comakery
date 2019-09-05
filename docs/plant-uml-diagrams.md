```plantuml
@startuml setup
!include style.iuml
actor "Deployer" as Deployer
participant "Token Contract" as Token
actor "Transfer\nAdmin" as TAdmin
actor "Reserve\nAdmin" as RAdmin
actor "Hot Wallet\nAdmin" as HAdmin

Deployer -> Token: constructor(\nreserveAddress,\ntransferAdminAddress,\nsymbol,\ndecimals,\ntotalSupply,\n...)
TAdmin -> Token: setAllowGroupTransfer(\nreserveTransferGroup,\nhotWalletTransferGroup,\nunrestrictedAddressTimeLock)
TAdmin -> Token: setRestrictions(\nreserveAddress,\nreserveTransferGroup,\nunrestrictedAddressTimelock,\nunrestrictedMaxTokenAmount)
TAdmin -> Token: setRestrictions(\nreserveAddress,\nhotWalletTransferGroup,\nunrestrictedAddressTimeLock,\nsensibleMaxAmountInHotWallet)
RAdmin -> Token: transfer(\nhotWallet,\namount)
TAdmin -> Token: setRestrictions(\ninvestorAddress,\nissuerTransferGroup,\naddressTimeLock,\nmaxTokens)
HAdmin -> Token: transfer(\ninvestorAddress,\namount)
activate Token
Token -> Token: detectTransferRestriction(\nfrom,\nto,\nvalue)

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
TAdmin -> Token: setAllowGroupTransfer(fromGroup, toGroup, afterTimestamp)

Investor -> Token: transfer(buyerAddress, amount)
activate Token
Token -> Token: detectTransferRestriction(from, to, value)

note left 
    **Transfer** or **Revert** depending on the result code
end note

@enduml
```
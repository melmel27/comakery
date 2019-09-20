const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Mutator calls and events", function (accounts) {
    var contractAdmin
    var reserveAdmin
    var transferAdmin
    var exchangeOmnibus
    var foreignInvestorS
    var domesticInvestorD
    
    var groupDefault
    var groupReserve
    var groupExchange
    var groupForeignS
    var groupDomesticD

    
  beforeEach(async function () {
    contractAdmin = accounts[0]
    reserveAdmin = accounts[1]
    transferAdmin = accounts[2]
    exchangeOmnibus = accounts[3]
    foreignInvestorS = accounts[5]
    domesticInvestorD = accounts[5]
    
    groupDefault = 0
    groupReserve = 1
    groupExchange = 2
    groupForeignS = 3
    groupDomesticD = 4

    token = await RestrictedToken.deployed()
  })

  it('initial setup after migrations', async () => {
    assert.equal(await token.totalSupply.call(), 100)
    assert.equal(await token.balanceOf.call(contractAdmin), 0, 'allocates no balance to the contractAdmin')
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocates all tokens to the reserve admin')
  })

  it('can be setup correctly for transfer restrictions', async() => {
    // configure initial transferAdmin
    await token.grantTransferAdmin(transferAdmin, {from: contractAdmin})

    // setup initial transfers groups
    // reserve account can transfer to anyone right away
    token.setAllowGroupTransfer(groupReserve, groupExchange, 1, {from: transferAdmin})
    token.setAllowGroupTransfer(groupReserve, groupDomesticD, 1, {from: transferAdmin})
    token.setAllowGroupTransfer(groupReserve, groupForeignS, 1, {from: transferAdmin})

    // exchange allows Reg S to withdraw to their own accounts
    token.setAllowGroupTransfer(groupExchange, groupForeignS, 1, {from: transferAdmin})

    // foreign Reg S can deposit into exchange accounts for trading on exchanges
    token.setAllowGroupTransfer(groupForeignS, groupExchange, 1, {from: transferAdmin})
    
    // distribute tokens to the exchange for regulated token sale
  })
})
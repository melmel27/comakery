const truffleAssert = require('truffle-assertions')
var RestrictedToken = artifacts.require("RestrictedToken")
var TransferRules = artifacts.require("TransferRules")

contract("Restricted token basics", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var unprivileged
  var token
  var transferAdmin

  beforeEach(async function () {
    contractAdmin = accounts[0]
    transferAdmin = accounts[1]
    walletsAdmin = accounts[2]
    reserveAdmin = accounts[3]

    unprivileged = accounts[5]
    alice = accounts[6]
    bob = accounts[7]

    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

    await token.grantWalletsAdmin(walletsAdmin, {
      from: contractAdmin
    })
    
    await token.setAllowGroupTransfer(0, 0, 1, {
      from: transferAdmin
    })
  })

  it('token initialization and high-level parameters', async () => {
    assert.equal(await token.symbol(), "xyz", "should return the token symbol")
    assert.equal(await token.name(), "Ex Why Zee", "should return the token name")
    assert.equal(await token.decimals(), 6, "should return the token decimals")
    assert.equal(await token.totalSupply(), 100, "should return the totalSupply")
  })

  it('token admin setup', async () => {
    assert.equal(await token.balanceOf(contractAdmin), 0, "Contract owner should have 0 balance")
    assert.equal(await token.balanceOf(reserveAdmin), 100, "Reserve admin should have the entire supply")
  })

  it('transfer restriction success', async () => {
    assert.equal(await token.detectTransferRestriction(contractAdmin, contractAdmin, 0), 0,
        "transfer should be unrestricted")
  })

  it('allowance return value and setting', async () => {
    assert.equal(await token.approve.call(unprivileged, 10, { from: bob }), true,
      "approval should return true to conform with OpenZeppelin interface expectations")
    await token.approve(unprivileged, 10, { from: bob })
    assert.equal(await token.allowance(bob, unprivileged), 10, "should have correct allowance")
  })

})

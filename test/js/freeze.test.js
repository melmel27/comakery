const truffleAssert = require('truffle-assertions')
var RestrictedToken = artifacts.require("RestrictedToken")
var TransferRules = artifacts.require("TransferRules")

contract("Freezes", function (accounts) {
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

    await token.setMaxBalance(alice, 1000, {
      from: walletsAdmin
    })

    await token.setMaxBalance(bob, 100, {
      from: walletsAdmin
    })

    await token.setAllowGroupTransfer(0, 0, 1, {
      from: transferAdmin
    })
    
  })

  it('Accounts can be frozen and prohibit outgoing transfers', async () => {
    await token.transfer(alice, 10, {
      from: reserveAdmin
    })

    await token.freeze(alice, true, {
      from: reserveAdmin
    })

    assert.equal(await token.detectTransferRestriction(alice, bob, 1), 5)

    await truffleAssert.reverts(token.transfer(bob, 2, {
      from: alice
    }), "SENDER ADDRESS IS FROZEN")
  })

  it('Accounts can be frozen by wallets admin', async () => {
    await token.freeze(alice, true, {
      from: walletsAdmin
    })

    assert.equal(await token.getFrozenStatus(alice), true)
  })

  it('Accounts can be frozen by reserve admin', async () => {
    await token.freeze(alice, true, {
      from: reserveAdmin
    })

    assert.equal(await token.getFrozenStatus(alice), true)
  })

  it('Accounts can be frozen and prohibit incoming transfers', async () => {
    await token.transfer(alice, 10, {
      from: reserveAdmin
    })

    await token.freeze(bob, true, {
      from: reserveAdmin
    })

    assert.equal(await token.detectTransferRestriction(alice, bob, 1), 9)

    await truffleAssert.reverts(token.transfer(bob, 2, {
      from: alice
    }), "RECIPIENT ADDRESS IS FROZEN")
  })

  it('contract admin can pause and unpause all transfers', async () => {
    assert.equal(await token.isPaused(), false)

    await token.pause({
      from: contractAdmin
    })
    assert.equal(await token.isPaused(), true)

    assert.equal(await token.detectTransferRestriction(reserveAdmin, alice, 1), 6)

    await token.unpause({
      from: contractAdmin
    })
    assert.equal(await token.isPaused(), false)
  })
})

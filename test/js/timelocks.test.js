const truffleAssert = require('truffle-assertions')
var RestrictedToken = artifacts.require("RestrictedToken")
var TransferRules = artifacts.require("TransferRules")

contract("Timelocks", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var unprivileged
  var token
  var transferAdmin

  var futureTimelock = Date.now() + 3600 * 24 * 30;

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

    await token.mint(alice, 60, {
        from: reserveAdmin
    })

    await token.setAddressPermissions(alice, 0, 0, 0, 0, false, {
        from: walletsAdmin
    })

    await token.setAllowGroupTransfer(0, 0, 1, {
      from: transferAdmin
    })
    
  })

  it('tokens should be transferable if no locks exist', async () => {
    await truffleAssert.passes(token.transfer(bob, 2, {
      from: alice
    }), "FAILED TO DO A SIMPLE TRANSFER")

  })

  it('one timelock correctly reserves its protected balance', async () => {
    await token.addLockUntil(alice, futureTimelock, 40, {
        from: walletsAdmin
    })

    assert.equal(await token.getCurrentlyLockedBalance(alice), 40)
    assert.equal(await token.getCurrentlyUnlockedBalance(alice), 20)

    await truffleAssert.passes(token.transfer(bob, 2, {
      from: alice
    }), "FAILED TO DO A SIMPLE TRANSFER WITHIN ALLOWED RANGE")

    await truffleAssert.reverts(token.transfer(bob, 22, {
      from: alice
    }), "SENDER TOKENS LOCKED")
  })

  it('timelock counter returns correct number of timelocks', async () => {
    await token.addLockUntil(alice, futureTimelock, 40, {
        from: walletsAdmin
    })

    assert.equal(await token.getTotalLocksUntil(alice), 1)

    await token.addLockUntil(alice, futureTimelock, 1, {
        from: walletsAdmin
    })

    assert.equal(await token.getTotalLocksUntil(alice), 1)

    await token.addLockUntil(alice, futureTimelock + 1, 1, {
        from: walletsAdmin
    })

    assert.equal(await token.getTotalLocksUntil(alice), 2)
  })

  it('timelock getter returns correct timestamps and amounts', async () => {
    await token.addLockUntil(alice, futureTimelock, 40, {
        from: walletsAdmin
    })

    let res = await token.getLockUntilIndexLookup(alice, 0)
    assert.equal(res.lockedUntil, futureTimelock)
    assert.equal(res.balanceLocked, 40)
  })

  it('multiple timelocks reserve separate balances', async () => {
    await token.addLockUntil(alice, futureTimelock, 30, {
        from: walletsAdmin
    })

    await token.addLockUntil(alice, futureTimelock + 5, 10, {
        from: walletsAdmin
    })

    assert.equal(await token.getCurrentlyLockedBalance(alice), 40)
    assert.equal(await token.getCurrentlyUnlockedBalance(alice), 20)

    await truffleAssert.passes(token.transfer(bob, 2, {
      from: alice
    }), "FAILED TO DO A SIMPLE TRANSFER WITHIN ALLOWED RANGE")

    await truffleAssert.reverts(token.transfer(bob, 22, {
      from: alice
    }), "SENDER TOKENS LOCKED")

  })

  it('timelocks at the same timestamp add up instead of creating new lock entries', async () => {
    assert.equal(await token.getTotalLocksUntil(alice), 0)

    await token.addLockUntil(alice, futureTimelock, 30, {
        from: walletsAdmin
    })
    assert.equal(await token.getTotalLocksUntil(alice), 1)

    await token.addLockUntil(alice, futureTimelock, 10, {
        from: walletsAdmin
    })
    assert.equal(await token.getTotalLocksUntil(alice), 1)

    assert.equal(await token.getCurrentlyLockedBalance(alice), 40)
    assert.equal(await token.getCurrentlyUnlockedBalance(alice), 20)

    await truffleAssert.passes(token.transfer(bob, 2, {
      from: alice
    }), "FAILED TO DO A SIMPLE TRANSFER WITHIN ALLOWED RANGE")

    await truffleAssert.reverts(token.transfer(bob, 22, {
      from: alice
    }), "SENDER TOKENS LOCKED")

  })

  it('timelocks can be removed by timestamp', async () => {
    await token.addLockUntil(alice, futureTimelock, 10, {
      from: walletsAdmin
    })
    await token.addLockUntil(alice, futureTimelock + 1, 10, {
      from: walletsAdmin
    })

    await truffleAssert.passes(token.removeLockUntilTimestampLookup(alice, futureTimelock, {
      from: walletsAdmin
    }), "Failed to remove a timelock by timestamp")

    assert.equal(await token.getTotalLocksUntil(alice), 1)
  })

  it('timelocks can be removed by index', async () => {
    await token.addLockUntil(alice, futureTimelock, 10, {
      from: walletsAdmin
    })
    await token.addLockUntil(alice, futureTimelock + 1, 10, {
      from: walletsAdmin
    })

    await truffleAssert.passes(token.removeLockUntilIndexLookup(alice, 0, {
      from: walletsAdmin
    }), "Failed to remove a timelock by index")

    assert.equal(await token.getTotalLocksUntil(alice), 1)
  })

  it('timelocks cannot be removed by a wrong index', async () => {
    await token.addLockUntil(alice, futureTimelock, 10, {
      from: walletsAdmin
    })

    await truffleAssert.fails(token.removeLockUntilIndexLookup(alice, 10, {
      from: walletsAdmin
    }), "Timelock index outside range")

    assert.equal(await token.getTotalLocksUntil(alice), 1)
  })

  it('multiple timelocks can be added and removed', async () => {
    await token.addLockUntil(alice, futureTimelock, 10, {
      from: walletsAdmin
    })
    await token.addLockUntil(alice, futureTimelock + 1, 10, {
      from: walletsAdmin
    })
    await token.addLockUntil(alice, futureTimelock + 3, 10, {
      from: walletsAdmin
    })

    await truffleAssert.passes(token.removeLockUntilTimestampLookup(alice, futureTimelock, {
      from: walletsAdmin
    }), "Failed to remove a timelock by timestamp")

    assert.equal(await token.getTotalLocksUntil(alice), 2)

    await truffleAssert.passes(token.removeLockUntilIndexLookup(alice, 0, {
      from: walletsAdmin
    }), "Failed to remove a timelock by index")

    assert.equal(await token.getTotalLocksUntil(alice), 1)

    await truffleAssert.passes(token.removeLockUntilIndexLookup(alice, 0, {
      from: walletsAdmin
    }), "Failed to remove a timelock by index")

    assert.equal(await token.getTotalLocksUntil(alice), 0)
  })
})

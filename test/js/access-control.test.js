const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Access control tests", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var unprivileged
  var token
  var transferAdmin

  beforeEach(async function () {
    contractAdmin = accounts[0]
    reserveAdmin = accounts[1]
    transferAdmin = accounts[2]

    unprivileged = accounts[5]

    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 100e6)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

  })

  it("an unprivileged user can call the public getter functions", async () => {
    assert.equal(await token.symbol.call({
      from: unprivileged
    }), "xyz")
    assert.equal(await token.name.call({
      from: unprivileged
    }), "Ex Why Zee")
    assert.equal(await token.decimals.call({
      from: unprivileged
    }), 6)
    assert.equal(await token.totalSupply.call({
      from: unprivileged
    }), 100)
    assert.equal(await token.balanceOf.call(contractAdmin, {
      from: unprivileged
    }), 0, 'allocates no balance to the contractAdmin')
    assert.equal(await token.balanceOf.call(reserveAdmin, {
      from: unprivileged
    }), 100, 'allocates all tokens to the token reserve admin')
  })

  it("an unprivileged user can check transfer restrictions", async () => {
    assert.equal(await token.detectTransferRestriction
      .call(contractAdmin, reserveAdmin, 1, {
        from: unprivileged
      }), 1)

    assert.equal(await token.messageForTransferRestriction.call(1, {
      from: unprivileged
    }), "GREATER THAN RECIPIENT MAX BALANCE")
  })

  it("only contractAdmin can pause transfers", async () => {
    await truffleAssert.passes(token.pause({
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.pause({
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only contractAdmin can unpause transfers", async () => {
    await truffleAssert.passes(token.unpause({
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.unpause({
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only contractAdmin can mint transfers", async () => {
    await truffleAssert.passes(token.mint(unprivileged, 123, {
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.mint(unprivileged, 123, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only contractAdmin can burn", async () => {
    assert.equal(await token.balanceOf(reserveAdmin), 100)

    await truffleAssert.passes(token.burn(reserveAdmin, 1, {
      from: contractAdmin
    }))

    assert.equal(await token.balanceOf(reserveAdmin), 99)

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.burn(reserveAdmin, 1, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only contractAdmin and transferAdmin can freeze", async () => {
    await truffleAssert.passes(token.freeze(reserveAdmin, true, {
      from: contractAdmin
    }))

    await truffleAssert.passes(token.freeze(reserveAdmin, true, {
      from: transferAdmin
    }))

    await truffleAssert.reverts(token.freeze(reserveAdmin, true, {
      from: reserveAdmin
    }), "DOES NOT HAVE TRANSFER ADMIN OR CONTRACT ADMIN ROLE")

    await truffleAssert.reverts(token.freeze(reserveAdmin, true, {
      from: unprivileged
    }), "DOES NOT HAVE TRANSFER ADMIN OR CONTRACT ADMIN ROLE")
  })

  it("only contractAdmin can grant transferAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.grantTransferAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.grantTransferAdmin(unprivileged, {
      from: contractAdmin
    }))
  })

  it("only contractAdmin can revoke transferAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.revokeTransferAdmin(transferAdmin, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.revokeTransferAdmin(transferAdmin, {
      from: contractAdmin
    }))
  })



  it("only contractAdmin can grant contractAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.grantContractAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.grantContractAdmin(unprivileged, {
      from: contractAdmin
    }))
  })

  it("only contractAdmin can revoke contractAdmin privileges", async () => {

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.revokeContractAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await token.grantContractAdmin(unprivileged, {
      from: contractAdmin
    })
    assert.equal(await token.contractAdminCount(), 2,
      "will need two contract admins so that there is the one required remaining after revokeContractAdmin contractAdmin")


    await truffleAssert.passes(token.revokeContractAdmin(unprivileged, {
      from: contractAdmin
    }))
  })

  it("only contractAdmin can change and upgrade the transfer rules with upgradeTransferRules", async () => {
    let nextTransferRules = await TransferRules.new()
    let transferRulesAddress = nextTransferRules.address
    await truffleAssert.passes(token.upgradeTransferRules(transferRulesAddress, {
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {

      await truffleAssert.reverts(token.upgradeTransferRules(transferRulesAddress, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only transferAdmin can setMaxBalance", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setMaxBalance(unprivileged, 100, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setMaxBalance(unprivileged, 100, {
      from: transferAdmin
    }))
  })

  it("only transferAdmin can setLockUntil", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setLockUntil(unprivileged, 17, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setLockUntil(unprivileged, 17, {
      from: transferAdmin
    }))
  })

  it("only transferAdmin can removeLockUntil", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.removeLockUntil(unprivileged, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.removeLockUntil(unprivileged, {
      from: transferAdmin
    }))
  })

  it("only transferAdmin can setTransferGroup", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setTransferGroup(unprivileged, 1, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setTransferGroup(unprivileged, 1, {
      from: transferAdmin
    }))
  })

  it("only transferAdmin can setAddressPermissions", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setAddressPermissions(unprivileged, 1, 17, 100, false, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setAddressPermissions(unprivileged, 1, 17, 100, false, {
      from: transferAdmin
    }))
  })

  it("only transferAdmin can setAllowGroupTransfer", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setAllowGroupTransfer(0, 1, 17, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setAllowGroupTransfer(0, 1, 17, {
      from: transferAdmin
    }))
  })

  it("must have at least one contractAdmin", async () => {
    // await token.grantContractAdmin(unprivileged, {from: contractAdmin})
    assert.equal(await token.contractAdminCount(), 1)

    await truffleAssert.reverts(token.revokeContractAdmin(contractAdmin, {
      from: contractAdmin
    }), "Must have at least one contract admin")

    assert.equal(await token.contractAdminCount(), 1)
  })

  it("keeps a count of the number of contract admins", async () => {
    assert.equal(await token.contractAdminCount(), 1)

    await token.grantContractAdmin(unprivileged, {
      from: contractAdmin
    })
    assert.equal(await token.contractAdminCount(), 2)

    await token.revokeContractAdmin(unprivileged, {
      from: contractAdmin
    })
    assert.equal(await token.contractAdminCount(), 1)
  })
})
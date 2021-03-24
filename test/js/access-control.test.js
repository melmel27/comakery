const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Access control tests", function (accounts) {
  var contractAdmin
  var transferAdmin
  var walletsAdmin
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

    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 100e6)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

    await token.grantWalletsAdmin(walletsAdmin, {
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
    await token.setMaxBalance(reserveAdmin, 5, {
        from: walletsAdmin
    })

    assert.equal(await token.detectTransferRestriction
      .call(contractAdmin, reserveAdmin, 10, {
        from: unprivileged
      }), 1)

    assert.equal(await token.messageForTransferRestriction.call(1, {
      from: unprivileged
    }), "GREATER THAN RECIPIENT MAX BALANCE")
  })

  it("only Contract Admin can pause transfers", async () => {
    await truffleAssert.passes(token.pause({
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {
        await truffleAssert.reverts(token.pause({
        from: from
        }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(walletsAdmin)
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
        }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only Reserve Admin can mint", async () => {
    await truffleAssert.passes(token.mint(unprivileged, 123, {
      from: reserveAdmin
    }))

    assert.equal(await token.balanceOf(unprivileged), 123)

    let checkRevertsFor = async (from) => {
        await truffleAssert.reverts(token.mint(unprivileged, 1, {
        from: from
        }), "DOES NOT HAVE RESERVE ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only Reserve Admin can burn", async () => {
    assert.equal(await token.balanceOf(reserveAdmin), 100)

    await truffleAssert.passes(token.burn(reserveAdmin, 1, {
      from: reserveAdmin
    }))

    assert.equal(await token.balanceOf(reserveAdmin), 99)


    let checkRevertsFor = async (from) => {
        await truffleAssert.reverts(token.burn(reserveAdmin, 1, {
        from: from
        }), "DOES NOT HAVE RESERVE ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only Wallets Admin and Reserve Admin can freeze", async () => {
    await truffleAssert.passes(token.freeze(reserveAdmin, true, {
      from: walletsAdmin
    }))

    await truffleAssert.passes(token.freeze(reserveAdmin, true, {
      from: reserveAdmin
    }))

    await truffleAssert.reverts(token.freeze(reserveAdmin, true, {
      from: contractAdmin
    }), "DOES NOT HAVE WALLETS ADMIN OR RESERVE ADMIN ROLE")

    await truffleAssert.reverts(token.freeze(reserveAdmin, true, {
      from: transferAdmin
    }), "DOES NOT HAVE WALLETS ADMIN OR RESERVE ADMIN ROLE")

    await truffleAssert.reverts(token.freeze(reserveAdmin, true, {
      from: unprivileged
    }), "DOES NOT HAVE WALLETS ADMIN OR RESERVE ADMIN ROLE")
  })

  // GRANTING AND REVOKING ADMIN PRIVILEGES

  it("only contractAdmin can grant contractAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.grantContractAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
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
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
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


  it("only contractAdmin can grant transferAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.grantTransferAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.grantTransferAdmin(unprivileged, {
      from: contractAdmin
    }))
  })

  it("only contractAdmin can revoke transferAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.revokeTransferAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await token.grantTransferAdmin(unprivileged, {
        from: contractAdmin
    })

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.revokeTransferAdmin(unprivileged, {
      from: contractAdmin
    }))
  })
  

  it("only contractAdmin can grant walletsAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.grantWalletsAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.grantWalletsAdmin(unprivileged, {
      from: contractAdmin
    }))
  })

  it("only contractAdmin can revoke walletsAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.revokeWalletsAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await token.grantWalletsAdmin(unprivileged, {
        from: contractAdmin
    })

    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.revokeWalletsAdmin(unprivileged, {
      from: contractAdmin
    }))
  })


  it("only contractAdmin can grant reserveAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.grantReserveAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.grantReserveAdmin(unprivileged, {
      from: contractAdmin
    }))
  })

  it("only contractAdmin can revoke reserveAdmin privileges", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.revokeReserveAdmin(unprivileged, {
        from: from
      }), "DOES NOT HAVE CONTRACT ADMIN ROLE")
    }

    await token.grantReserveAdmin(unprivileged, {
        from: contractAdmin
    })

    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.revokeReserveAdmin(unprivileged, {
      from: contractAdmin
    }))
  })


  // TRANSFER ADMIN FUNCTIONS 
  
  it("only Transfer Admin can change and upgrade the transfer rules with upgradeTransferRules", async () => {
    let nextTransferRules = await TransferRules.new()
    let transferRulesAddress = nextTransferRules.address
    await truffleAssert.passes(token.upgradeTransferRules(transferRulesAddress, {
      from: transferAdmin
    }))

    let checkRevertsFor = async (from) => {

      await truffleAssert.reverts(token.upgradeTransferRules(transferRulesAddress, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })


  it("only transferAdmin can setAllowGroupTransfer", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setAllowGroupTransfer(0, 1, 17, {
        from: from
      }), "DOES NOT HAVE TRANSFER ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(walletsAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setAllowGroupTransfer(0, 1, 17, {
      from: transferAdmin
    }))
  })

  // WALLETS ADMIN FUNCTIONS 
  
  it("only Wallets Admin can setMaxBalance", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setMaxBalance(unprivileged, 100, {
        from: from
      }), "DOES NOT HAVE WALLETS ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setMaxBalance(unprivileged, 100, {
      from: walletsAdmin
    }))
  })

  it("only Wallets Admin can setLockUntil", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setLockUntil(unprivileged, 17, {
        from: from
      }), "DOES NOT HAVE WALLETS ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setLockUntil(unprivileged, 17, {
      from: walletsAdmin
    }))
  })

  it("only Wallets Admin can removeLockUntil", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.removeLockUntil(unprivileged, {
        from: from
      }), "DOES NOT HAVE WALLETS ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.removeLockUntil(unprivileged, {
      from: walletsAdmin
    }))
  })

  it("only Wallets Admin can setTransferGroup", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setTransferGroup(unprivileged, 1, {
        from: from
      }), "DOES NOT HAVE WALLETS ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setTransferGroup(unprivileged, 1, {
      from: walletsAdmin
    }))
  })

  it("only Wallets Admin can setAddressPermissions", async () => {
    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.setAddressPermissions(unprivileged, 1, 17, 100, false, {
        from: from
      }), "DOES NOT HAVE WALLETS ADMIN ROLE")
    }

    await checkRevertsFor(contractAdmin)
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.setAddressPermissions(unprivileged, 1, 17, 100, false, {
      from: walletsAdmin
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

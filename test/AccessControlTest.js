const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");

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

    token = await RestrictedToken.new(contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100)
    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

  })

  it('contract contractAdmin is not the same address as treasury admin', async () => {
    assert.equal(await token.balanceOf.call(contractAdmin), 0, 'allocates no balance to the contractAdmin')
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
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

  it("only contractAdmin can burnFrom", async () => {
    await truffleAssert.passes(token.burnFrom(reserveAdmin, 1, {
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.burnFrom(reserveAdmin, 1, {
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
      await truffleAssert.reverts(token.revokeContractAdmin(contractAdmin, {
        from: from
      }), "DOES NOT HAVE CONTRACT OWNER ROLE")
    }

    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)

    await truffleAssert.passes(token.revokeContractAdmin(contractAdmin, {
      from: contractAdmin
    }))
  })
})
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

    token = await RestrictedToken.new(contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100);
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
      }), "DOES_NOT_HAVE_CONTRACT_OWNER_ROLE")
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
      }), "DOES_NOT_HAVE_CONTRACT_OWNER_ROLE")
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
      }), "DOES_NOT_HAVE_CONTRACT_OWNER_ROLE")
    }
    
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })

  it("only contractAdmin can burnFrom transfers", async () => {
    await truffleAssert.passes(token.burnFrom(reserveAdmin, 1, {
      from: contractAdmin
    }))

    let checkRevertsFor = async (from) => {
      await truffleAssert.reverts(token.burnFrom(reserveAdmin, 1, {
        from: from
      }), "DOES_NOT_HAVE_CONTRACT_OWNER_ROLE")
    }
    
    await checkRevertsFor(transferAdmin)
    await checkRevertsFor(reserveAdmin)
    await checkRevertsFor(unprivileged)
  })
})
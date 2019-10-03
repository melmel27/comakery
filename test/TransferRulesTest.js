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
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

  })

  it('contract contractAdmin is not the same address as treasury admin', async () => {
    assert.equal(await token.balanceOf.call(contractAdmin), 0, 'allocates no balance to the contractAdmin')
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
  })

  it('returns true and false values for getAllowTransfer', async () => {
    let defaultGroup = 0
    await token.setAllowGroupTransfer(defaultGroup, defaultGroup, 1, {
      from: transferAdmin
    })
    
    assert.equal(await token.getAllowTransfer
      .call(reserveAdmin, unprivileged, 0, {
        from: unprivileged
      }), false, "should not allow transfer at time 0")

    assert.equal(await token.getAllowTransfer
      .call(reserveAdmin, unprivileged, 2, {
        from: unprivileged
      }), true, "should allow transfer at time 1")
  })
})
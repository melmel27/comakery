const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Access control tests", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var transferAdmin
  var recipient
  var unprivileged
  var defaultGroup
  var token

  beforeEach(async function () {
    contractAdmin = accounts[0]
    reserveAdmin = accounts[1]
    transferAdmin = accounts[2]
    recipient = accounts[3]
    unprivileged = accounts[5]
    defaultGroup = 0

    token = await RestrictedToken.new(contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

    await token.setAllowGroupTransfer(0, 0, 1, {
      from: transferAdmin
    })

    await token.setAccountPermissions(reserveAdmin, defaultGroup, 1, 1000, false, {
      from: transferAdmin
    })

    await token.setAccountPermissions(recipient, defaultGroup, 1, 1000, false, {
      from: transferAdmin
    })

  })

  it('events', async () => {
    assert.equal(await token.balanceOf.call(contractAdmin), 0, 'allocates no balance to the contractAdmin')
  })

  it("only contractAdmin and transferAdmin can freeze", async () => {
    let tx = await token.transfer(recipient, 10, {
      from: reserveAdmin
    })

    truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
      assert.equal(ev.from, reserveAdmin)
      assert.equal(ev.to, recipient)
      assert.equal(ev.value, 10)
      return true
    })
  })
})
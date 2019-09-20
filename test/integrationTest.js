const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Mutator calls and events", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var transferAdmin
  var recipient
  var unprivileged
  var defaultGroup
  var token
  var startingRules

  beforeEach(async function () {
    contractAdmin = accounts[0]
    reserveAdmin = accounts[1]
    transferAdmin = accounts[2]
    recipient = accounts[3]
    unprivileged = accounts[5]
    defaultGroup = 0

    token = await RestrictedToken.deployed()
  })

  it('initial setup after migrations', async () => {
    assert.equal(await token.totalSupply.call(), 100)
    assert.equal(await token.balanceOf.call(contractAdmin), 0, 'allocates no balance to the contractAdmin')
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocated tokens to the reserve admin')
  })
})
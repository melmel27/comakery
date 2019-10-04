const BN = web3.utils.BN;
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

  it('has the correct test connfiguration', async() => {
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
  })

  it('test burning', async () => {
    await token.burnFrom(reserveAdmin, 17);
    assert.equal(await token.balanceOf.call(reserveAdmin), 83)
  })

  it('test cannot burn more than address balance', async () => {
    await truffleAssert.reverts(token.burnFrom(reserveAdmin, 101, {
      from: contractAdmin
    }), "Insufficent tokens to burn")
  })
})
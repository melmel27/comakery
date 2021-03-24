const BN = web3.utils.BN;
const truffleAssert = require('truffle-assertions');

var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Token minting tests", function (accounts) {
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
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1000)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

  })

  it('has the correct test connfiguration', async () => {
    assert.equal(await token.balanceOf(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
  })

  it('can burn', async () => {
    await token.burn(reserveAdmin, 17, {
        from: reserveAdmin
    });
    assert.equal(await token.balanceOf(reserveAdmin), 83)
  })

  it('cannot burn more than address balance', async () => {
    await truffleAssert.reverts(token.burn(reserveAdmin, 101, {
      from: reserveAdmin
    }), "Insufficent tokens to burn")
  })

  it('cannot mint more than the maxTotalSupply', async () => {
    assert.equal(await token.maxTotalSupply(), 1000, 'should have max total supply')

    await truffleAssert.reverts(token.mint(reserveAdmin, 901, {
      from: reserveAdmin
    }), "Cannot mint more than the max total supply")

    assert.equal(await token.totalSupply(), 100, 'should not have increased the total tokens')

    await token.mint(reserveAdmin, 900, {
      from: reserveAdmin
    })

    assert.equal(await token.totalSupply(), 1000, 'should have increased the total tokens')
    assert.equal(await token.balanceOf(reserveAdmin), 1000,
      'should have minted the max number of tokens into the reserveAdmin address')
  })
})

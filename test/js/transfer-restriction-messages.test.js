const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Transfer restriction messages test", function (accounts) {
  var contractAdmin
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

    await token.mint(alice, 40, {
        from: reserveAdmin
    });
  })

  it('Transfer restriction messages are returned correctly', async () => {
    assert.equal(await token.messageForTransferRestriction(0)
      , "SUCCESS"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(1)
      , "GREATER THAN RECIPIENT MAX BALANCE"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(2)
      , "SENDER TOKENS LOCKED"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(3)
      , "DO NOT SEND TO TOKEN CONTRACT"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(4)
      , "DO NOT SEND TO EMPTY ADDRESS"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(5)
      , "SENDER ADDRESS IS FROZEN"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(6)
      , "ALL TRANSFERS PAUSED"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(7)
      , "TRANSFER GROUP NOT APPROVED"
      , "wrong message");
    assert.equal(await token.messageForTransferRestriction(8)
      , "TRANSFER GROUP NOT ALLOWED UNTIL LATER"
      , "wrong message");
    })
})

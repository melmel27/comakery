const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Initialization tests", function (accounts) {
  var contractAdmin
  var reserveAdmin
  var unpermissioned
  var emptyAddress = web3.utils.padLeft(0x0, 40)

  beforeEach(async function () {
    contractAdmin = accounts[0]
    reserveAdmin = accounts[1]
    unpermissioned = accounts[2]
  })

  it("cannot setup the contract with valid addresses", async () => {
    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100)
  })

  it("cannot set token owner address to 0x0", async () => {
    let rules = await TransferRules.new()

    await truffleAssert.reverts(
      RestrictedToken.new(rules.address, emptyAddress, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, {
        from: unpermissioned
      }),
      "Token owner address cannot be 0x0")
  })

  it("cannot set token reserve admin address to 0x0", async () => {
    let rules = await TransferRules.new()

    await truffleAssert.reverts(
      RestrictedToken.new(rules.address, contractAdmin, emptyAddress, "xyz", "Ex Why Zee", 6, 100, {
        from: unpermissioned
      }),
      "Token reserve admin address cannot be 0x0")
  })

  it("cannot set transfer rules address to 0x0", async () => {
    let rules = await TransferRules.new()

    await truffleAssert.reverts(
      RestrictedToken.new(emptyAddress, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, {
        from: unpermissioned
      }),
      "Transfer rules address cannot be 0x0")
  })
})
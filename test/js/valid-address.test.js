const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Validatsion of addresses", function (accounts) {
  var contractAdmin
  var transferAdmin
  var reserveAdmin
  var unpermissioned
  var emptyAddress = web3.utils.padLeft(0x0, 40)
  var futureTimestamp = Date.now() + 3600;

  beforeEach(async function () {
    contractAdmin = accounts[0]
    transferAdmin = accounts[1]
    reserveAdmin = accounts[2]
    unpermissioned = accounts[3]
  })

  it("cannot setup the contract with valid addresses", async () => {
    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6)
  })

  it("cannot set token owner address to 0x0", async () => {
    let rules = await TransferRules.new()

    await truffleAssert.reverts(
      RestrictedToken.new(rules.address, emptyAddress, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6, {
        from: unpermissioned
      }),
      "Token owner address cannot be 0x0")
  })

  it("cannot set token reserve admin address to 0x0", async () => {
    let rules = await TransferRules.new()

    await truffleAssert.reverts(
      RestrictedToken.new(rules.address, contractAdmin, emptyAddress, "xyz", "Ex Why Zee", 6, 100, 1e6, {
        from: unpermissioned
      }),
      "Token reserve admin address cannot be 0x0")
  })

  it("cannot set transfer rules address to 0x0", async () => {
    await truffleAssert.reverts(
      RestrictedToken.new(emptyAddress, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6, {
        from: unpermissioned
      }),
      "Transfer rules address cannot be 0x0")
  })

  describe("Mutator addresses cannot be 0x0 for", async () => {
    var token
    var expectedError = "Address cannot be 0x0"
    beforeEach(async () => {
      let rules = await TransferRules.new()
      token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 1e6, 100)
    })

    it("grantTransferAdmin", async () => {
      await truffleAssert.reverts(
        token.grantTransferAdmin(emptyAddress, {
          from: unpermissioned
        }), expectedError)
    })

    it("revokeTransferAdmin", async () => {
      await truffleAssert.reverts(
        token.revokeTransferAdmin(emptyAddress, {
          from: unpermissioned
        }), expectedError)
    })

    it("grantContractAdmin", async () => {
      await truffleAssert.reverts(
        token.grantContractAdmin(emptyAddress, {
          from: unpermissioned
        }), expectedError)
    })

    it("revokeContractAdmin", async () => {
      await truffleAssert.reverts(
        token.revokeContractAdmin(emptyAddress, {
          from: unpermissioned
        }), expectedError)
    })

    it("setMaxBalance", async () => {
      await truffleAssert.reverts(
        token.setMaxBalance(emptyAddress, 100, {
          from: unpermissioned
        }), expectedError)
    })

    it("addLockUntil", async () => {
      await truffleAssert.reverts(
        token.addLockUntil(emptyAddress, futureTimestamp, 100, {
          from: unpermissioned
        }), expectedError)
    })

    it("removeLockUntilTimestampLookup", async () => {
      await truffleAssert.reverts(
        token.removeLockUntilTimestampLookup(emptyAddress, futureTimestamp, {
          from: unpermissioned
        }), expectedError)
    })

    it("setTransferGroup", async () => {
      await truffleAssert.reverts(
        token.setTransferGroup(emptyAddress, 1, {
          from: unpermissioned
        }), expectedError)
    })

    it("freeze", async () => {
      await truffleAssert.reverts(
        token.freeze(emptyAddress, true, {
          from: unpermissioned
        }), expectedError)
    })

    it("setAddressPermissions", async () => {
      await truffleAssert.reverts(
        token.setAddressPermissions(emptyAddress, 1, 0, 0, 4, true, {
          from: unpermissioned
        }), expectedError)
    })

    it("burn", async () => {
      await truffleAssert.reverts(
        token.burn(emptyAddress, 10, {
          from: unpermissioned
        }), expectedError)
    })

    it("mint", async () => {
      await truffleAssert.reverts(
        token.mint(emptyAddress, 10, {
          from: unpermissioned
        }), expectedError)
    })

    it("upgradeTransferRules", async () => {
      await token.grantTransferAdmin(transferAdmin, {
          from: contractAdmin
      })

      await truffleAssert.reverts(
        token.upgradeTransferRules(emptyAddress, {
          from: transferAdmin
        }), expectedError)
    })

    it("transfer", async () => {
      await truffleAssert.reverts(
        token.transfer(emptyAddress, 10, {
          from: unpermissioned
        }), expectedError)
    })

    it("approve", async () => {
      await truffleAssert.reverts(
        token.approve(emptyAddress, 1, {
          from: unpermissioned
        }), "ERC20: approve to the zero address.")
    })

    it("safeApprove", async () => {
      await truffleAssert.reverts(
        token.safeApprove(emptyAddress, 1, {
          from: unpermissioned
        }), "ERC20: approve to the zero address.")
    })

    it("transferFrom", async () => {
      await truffleAssert.reverts(
        token.transferFrom(emptyAddress, unpermissioned, 1, {
          from: unpermissioned
        }), expectedError)
    })

    it("transferFrom", async () => {
      await truffleAssert.reverts(
        token.transferFrom(unpermissioned, emptyAddress, 1, {
          from: unpermissioned
        }), expectedError)
    })
  })
})

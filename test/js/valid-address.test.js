const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Validate", function (accounts) {
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
    await truffleAssert.reverts(
      RestrictedToken.new(emptyAddress, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, {
        from: unpermissioned
      }),
      "Transfer rules address cannot be 0x0")
  })

  describe("Mutator addresses cannot be 0x0 for", async () => {
    var token
    var expectedError = "Address cannot be 0x0"
    beforeEach(async () => {
      let rules = await TransferRules.new()
      token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100)
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

    it("setTimeLock", async () => {
      await truffleAssert.reverts(
        token.setTimeLock(emptyAddress, 100, {
          from: unpermissioned
        }), expectedError)
    })

    it("removeTimeLock", async () => {
      await truffleAssert.reverts(
        token.removeTimeLock(emptyAddress, {
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
        token.setAddressPermissions(emptyAddress, 1, 3, 4, true, {
          from: unpermissioned
        }), expectedError)
    })

    it("burnFrom", async () => {
      await truffleAssert.reverts(
        token.burnFrom(emptyAddress, 10, {
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
      await truffleAssert.reverts(
        token.upgradeTransferRules(emptyAddress, {
          from: contractAdmin
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
        }), expectedError)
    })

    it("safeApprove", async () => {
      await truffleAssert.reverts(
        token.safeApprove(emptyAddress, 1, 0, 0, {
          from: unpermissioned
        }), expectedError)
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
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

    let rules = await TransferRules.new()
    token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100)

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

  it("transfer with Transfer event", async () => {
    let tx = await token.transfer(recipient, 10, {
      from: reserveAdmin
    })

    truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
      assert.equal(ev.from, reserveAdmin)
      assert.equal(ev.to, recipient)
      assert.equal(ev.value, 10)
      return true
    })

    assert.equal(await token.balanceOf(recipient), 10)
  })

  it("transfer with Transfer event", async () => {
    let tx = await token.transfer(recipient, 10, {
      from: reserveAdmin
    })

    truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
      assert.equal(ev.from, reserveAdmin)
      assert.equal(ev.to, recipient)
      assert.equal(ev.value, 10)
      return true
    })

    assert.equal(await token.balanceOf(recipient), 10)
  })

  it("grantTransferAdmin with RoleChange event", async () => {
    let tx = await token.grantTransferAdmin(recipient, {
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx, 'RoleChange', (ev) => {
      assert.equal(ev.grantor, contractAdmin)
      assert.equal(ev.grantee, recipient)
      assert.equal(ev.role, "TransferAdmin")
      assert.equal(ev.status, true)
      return true
    })
  })

  it("revokeTransferAdmin with RoleChange event", async () => {
    await token.grantTransferAdmin(recipient, {
      from: contractAdmin
    })

    let tx = await token.revokeTransferAdmin(recipient, {
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx, 'RoleChange', (ev) => {
      assert.equal(ev.grantor, contractAdmin)
      assert.equal(ev.grantee, recipient)
      assert.equal(ev.role, "TransferAdmin")
      assert.equal(ev.status, false)
      return true
    })
  })

  it("grantContractAdmin with RoleChange event", async () => {
    let tx = await token.grantContractAdmin(recipient, {
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx, 'RoleChange', (ev) => {
      assert.equal(ev.grantor, contractAdmin)
      assert.equal(ev.grantee, recipient)
      assert.equal(ev.role, "ContractAdmin")
      assert.equal(ev.status, true)
      return true
    })
  })

  it("revokeContractAdmin with RoleChange event", async () => {
    await token.grantContractAdmin(recipient, {
      from: contractAdmin
    })

    let tx = await token.revokeContractAdmin(recipient, {
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx, 'RoleChange', (ev) => {
      assert.equal(ev.grantor, contractAdmin)
      assert.equal(ev.grantee, recipient)
      assert.equal(ev.role, "ContractAdmin")
      assert.equal(ev.status, false)
      return true
    })
  })


  it("setMaxBalance with events", async () => {
    let tx = await token.setMaxBalance(recipient, 100, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressMaxBalance', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.account, recipient)
      assert.equal(ev.value, 100)
      return true
    })

    assert.equal(await token.getMaxBalance(recipient), 100)
  })

  it("setTimeLock with events", async () => {
    let tx = await token.setTimeLock(recipient, 97, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressTimeLock', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.account, recipient)
      assert.equal(ev.value, 97)
      return true
    })

    assert.equal(await token.getTimeLock(recipient), 97)

    let tx2 = await token.removeTimeLock(recipient, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx2, 'AddressTimeLock', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.account, recipient)
      assert.equal(ev.value, 0)
      return true
    })

    assert.equal(await token.getTimeLock(recipient), 0)
  })

  it("setGroup with events", async () => {
    let tx = await token.setGroup(recipient, 9, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressTransferGroup', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.account, recipient)
      assert.equal(ev.value, 9)
      return true
    })

    assert.equal(await token.getTransferGroup(recipient), 9)
  })

  it("freeze with events", async () => {
    let tx = await token.freeze(recipient, true, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressFrozen', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.account, recipient)
      assert.equal(ev.status, true)
      return true
    })

    assert.equal(await token.frozen(recipient), true)

    let tx2 = await token.freeze(recipient, false, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx2, 'AddressFrozen', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.account, recipient)
      assert.equal(ev.status, false)
      return true
    })

    assert.equal(await token.frozen(recipient), false)
  })

  it("setAllowGroupTransfer with events", async () => {
    let tx = await token.setAllowGroupTransfer(0, 1, 203, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'AllowGroupTransfer', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.fromGroup, 0)
      assert.equal(ev.toGroup, 1)
      assert.equal(ev.transferAfter, 203)
      return true
    })

    assert.equal(await token.getAllowGroupTransfer(0, 1, 204), true)
  })

  it("burnFrom with events", async () => {
    let tx = await token.burnFrom(reserveAdmin, 17, {
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx, 'Burn', (ev) => {
      assert.equal(ev.admin, contractAdmin)
      assert.equal(ev.account, reserveAdmin)
      assert.equal(ev.value, 17)
      return true
    })

    assert.equal(await token.balanceOf(reserveAdmin), 83)
  })
})
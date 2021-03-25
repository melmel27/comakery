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
  var emptyAddress = web3.utils.padLeft(0x0, 40)
  var futureTimestamp = Date.now() + 3600 * 24 * 30;

  beforeEach(async function () {
    contractAdmin = accounts[0]
    transferAdmin = accounts[1]
    walletsAdmin = accounts[2]
    reserveAdmin = accounts[3]
    recipient = accounts[4]
    unprivileged = accounts[5]
    defaultGroup = 0

    startingRules = await TransferRules.new()
    token = await RestrictedToken.new(startingRules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6)

    await token.grantTransferAdmin(transferAdmin, {
      from: contractAdmin
    })

    await token.grantWalletsAdmin(walletsAdmin, {
        from: contractAdmin
    })

    await token.setAllowGroupTransfer(0, 0, 1, {
      from: transferAdmin
    })

    await token.setAddressPermissions(reserveAdmin, defaultGroup, 0, 0, 1000, false, {
      from: walletsAdmin
    })

    await token.setAddressPermissions(recipient, defaultGroup, 0, 0, 1000, false, {
      from: walletsAdmin
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
      from: walletsAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressMaxBalance', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, recipient)
      assert.equal(ev.value, 100)
      return true
    })

    assert.equal(await token.getMaxBalance(recipient), 100)
  })

  it("addLockUntil with events", async () => {
    let tx = await token.addLockUntil(recipient, futureTimestamp, 97, {
      from: walletsAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressTimeLockAdded', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, recipient)
      assert.equal(ev.timestamp, futureTimestamp)
      assert.equal(ev.value, 97)
      return true
    })

    assert.equal(await token.getLockUntilAtTimestamp(recipient, futureTimestamp), 97)

    let tx2 = await token.removeLockUntilIndexLookup(recipient, 0, {
      from: walletsAdmin
    })

    truffleAssert.eventEmitted(tx2, 'AddressTimeLockRemoved', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, recipient)
      assert.equal(ev.timestamp, futureTimestamp)
      assert.equal(ev.unlockedValue, 97)
      return true
    })

    assert.equal(await token.getCurrentlyLockedBalance(recipient), 0)
  })

  it("setTransferGroup with events", async () => {
    let tx = await token.setTransferGroup(recipient, 9, {
      from: walletsAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressTransferGroup', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, recipient)
      assert.equal(ev.value, 9)
      return true
    })

    assert.equal(await token.getTransferGroup(recipient), 9)
  })
  
  it("setAddressPermissions with events from all inner function calls", async () => {
    let tx = await token.setAddressPermissions(unprivileged, 9, 0, 0, 1000, true, {
      from: walletsAdmin
    })
    truffleAssert.eventEmitted(tx, 'AddressTransferGroup', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, unprivileged)
      assert.equal(ev.value, 9)
      return true
    })

    truffleAssert.eventEmitted(tx, 'AddressMaxBalance', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, unprivileged)
      assert.equal(ev.value, 1000)
      return true
    })

    truffleAssert.eventEmitted(tx, 'AddressFrozen', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, unprivileged)
      assert.equal(ev.status, true)
      return true
    })
    
    assert.equal(await token.getTransferGroup(unprivileged), 9)
    assert.equal(await token.getCurrentlyLockedBalance(recipient), 0)
    assert.equal(await token.getMaxBalance(unprivileged), 1000)
    assert.equal(await token.getFrozenStatus(unprivileged), true)  
  })
  
  it("freeze with events", async () => {
    let tx = await token.freeze(recipient, true, {
      from: walletsAdmin
    })

    truffleAssert.eventEmitted(tx, 'AddressFrozen', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, recipient)
      assert.equal(ev.status, true)
      return true
    })

    assert.equal(await token.getFrozenStatus(recipient), true)

    let tx2 = await token.freeze(recipient, false, {
      from: walletsAdmin
    })

    truffleAssert.eventEmitted(tx2, 'AddressFrozen', (ev) => {
      assert.equal(ev.admin, walletsAdmin)
      assert.equal(ev.addr, recipient)
      assert.equal(ev.status, false)
      return true
    })

    assert.equal(await token.getFrozenStatus(recipient), false)
  })

  it("setAllowGroupTransfer with event and retreive wiith getAllowGroupTransferTime", async () => {
    let tx = await token.setAllowGroupTransfer(0, 1, 203, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'AllowGroupTransfer', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.fromGroup, 0)
      assert.equal(ev.toGroup, 1)
      assert.equal(ev.lockedUntil, 203)
      return true
    })

    assert.equal(await token.getAllowGroupTransferTime(0, 1), 203)
  })

  it("burn with events", async () => {
    let tx = await token.burn(reserveAdmin, 17, {
      from: reserveAdmin
    })

    truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
      assert.equal(ev.from, reserveAdmin)
      assert.equal(ev.to, emptyAddress)
      assert.equal(ev.value, 17)
      return true
    })

    assert.equal(await token.balanceOf(reserveAdmin), 83)
    assert.equal(await token.totalSupply(), 83)
  })

  it("mint with events", async () => {
    let tx = await token.mint(recipient, 17, {
      from: reserveAdmin
    })

    truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
      assert.equal(ev.from, emptyAddress)
      assert.equal(ev.to, recipient)
      assert.equal(ev.value, 17)
      return true
    })

    assert.equal(await token.balanceOf(recipient), 17)
  })

  it("pause/unpause with events", async () => {
    assert.equal(await token.isPaused(), false)

    let tx = await token.pause({
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx, 'Pause', (ev) => {
      assert.equal(ev.admin, contractAdmin)
      assert.equal(ev.status, true)
      return true
    })

    assert.equal(await token.isPaused(), true)

    let tx2 = await token.unpause({
      from: contractAdmin
    })

    truffleAssert.eventEmitted(tx2, 'Pause', (ev) => {
      assert.equal(ev.admin, contractAdmin)
      assert.equal(ev.status, false)
      return true
    })

    assert.equal(await token.isPaused(), false)
  })

  it("upgrade transfer rules with events", async () => {
    let newRules = await TransferRules.new()
    let tx = await token.upgradeTransferRules(newRules.address, {
      from: transferAdmin
    })

    truffleAssert.eventEmitted(tx, 'Upgrade', (ev) => {
      assert.equal(ev.admin, transferAdmin)
      assert.equal(ev.oldRules, startingRules.address)
      assert.equal(ev.newRules, newRules.address)
      return true
    })

    assert.equal(await token.transferRules.call(), newRules.address)
  })

  it("can check if an address has TransferAdmin permissions", async () => {
    assert.equal(await token.checkTransferAdmin.call(transferAdmin), true)
    assert.equal(await token.checkTransferAdmin.call(unprivileged), false)
  })

  it("can check if an address has ContractAdmin permissions", async () => {
    assert.equal(await token.checkContractAdmin.call(contractAdmin), true)
    assert.equal(await token.checkContractAdmin.call(unprivileged), false)
  })
})

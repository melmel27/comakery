const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("ERC20 functionality", function (accounts) {
    var contractAdmin
    var alice
    var bob
    var token

    beforeEach(async function () {
        contractAdmin = accounts[0]
        transferAdmin = accounts[1]
        walletsAdmin = accounts[2]
        alice = accounts[3]
        bob = accounts[4]
        charlie = accounts[5]

        defaultGroup = 0

        let rules = await TransferRules.new()
        token = await RestrictedToken.new(rules.address, contractAdmin, alice, "xyz", "Ex Why Zee", 6, 100, 1e6)

        await token.grantTransferAdmin(transferAdmin, {
            from: contractAdmin
        })

        await token.grantWalletsAdmin(walletsAdmin, {
            from: contractAdmin
        })

        await token.setAllowGroupTransfer(defaultGroup, defaultGroup, 1, {
            from: transferAdmin
        })

        await token.setAddressPermissions(bob, defaultGroup, 1, 200, false, {
            from: walletsAdmin
        })
    })

    it('cannot receive tokens by default even in default group 0', async () => {
        await token.setMaxBalance(charlie, 10, {
            from: walletsAdmin
        })

        await truffleAssert.reverts(token.transfer(charlie, 50, {
            from: alice
        }), "GREATER THAN RECIPIENT MAX BALANCE")
    })

    it('can do a simple transfer', async () => {
        let tx = await token.transfer(bob, 50, {
            from: alice
        })

        truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
            assert.equal(ev.from, alice)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 50)
            return true
        })

        assert.equal(await token.balanceOf.call(bob), 50)
    })

    it('can approve someone else', async () => {
        let tx = await token.approve(bob, 20, {
            from: alice
        })

        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value, 20)
            return true
        })

        assert.equal(await token.allowance.call(alice, bob), 20)
        assert.equal(await token.balanceOf.call(bob), 0)
        assert.equal(await token.balanceOf.call(alice), 100)

        await token.transferFrom(alice, bob, 20, {
            from: bob
        })

        assert.equal(await token.balanceOf.call(bob), 20)
        assert.equal(await token.balanceOf.call(alice), 80)

        await truffleAssert.reverts(token.transferFrom(alice, bob, 1, {
            from: bob
        }), "The approved allowance is lower than the transfer amount")
    })

    it('can safeApprove only when safeApprove value is 0', async () => {
        assert.equal(await token.allowance(alice, bob), 0)

        let tx = await token.safeApprove(bob, 20, {
            from: alice
        })

        assert.equal(await token.allowance(alice, bob), 20)

        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value, 20)
            return true
        })

        await truffleAssert.reverts(token.safeApprove(bob, 1, {
            from: alice
        }), "Cannot approve from non-zero to non-zero allowance")

        let tx2 = await token.safeApprove(bob, 0, {
            from: alice
        })
        
        truffleAssert.eventEmitted(tx2, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value, 0)
            return true
        })
        
        assert.equal(await token.allowance(alice, bob), 0)
    })

    it('can increaseAllowance', async () => {
        token.safeApprove(bob, 20, {
            from: alice
        })

        let tx = await token.increaseAllowance(bob, 2, {
            from: alice
        })

        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value,22)
            return true
        })
        
        assert.equal(await token.allowance(alice, bob), 22)
    })    

    it('can increaseAllowance from 0', async () => {
        let tx = await token.increaseAllowance(bob, 2, {
            from: alice
        })

        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value,2)
            return true
        })
        
        assert.equal(await token.allowance(alice, bob), 2)
    })    

    it('can decreaseAllowance', async () => {
        token.safeApprove(bob, 20, {
            from: alice
        })

        let tx = await token.decreaseAllowance(bob, 2, {
            from: alice
        })

        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value,18)
            return true
        })
        
        assert.equal(await token.allowance(alice, bob), 18)
    })

    it('cannot transfer more tokens than you have', async () => {
        await truffleAssert.reverts(token.transfer(bob, 101, {
            from: alice
        }), "Insufficent tokens")
    })

    it('cannot transfer more tokens than the account you are transferring from has', async () => {
        assert.equal(await token.balanceOf.call(alice), 100)
        await token.safeApprove(bob, 150, {
            from: alice
        })

        await truffleAssert.reverts(token.transferFrom(alice, bob, 101, {
            from: bob
        }), "Insufficent tokens")
        assert.equal(await token.balanceOf.call(alice), 100)
    })
})

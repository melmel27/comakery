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
        alice = accounts[1]
        bob = accounts[2]
        charlie = accounts[3]

        defaultGroup = 0

        let rules = await TransferRules.new()
        token = await RestrictedToken.new(rules.address, contractAdmin, alice, "xyz", "Ex Why Zee", 6, 100)

        await token.grantTransferAdmin(contractAdmin, {
            from: contractAdmin
        })

        await token.setAllowGroupTransfer(defaultGroup, defaultGroup, 1, {
            from: contractAdmin
        })

        await token.setAccountPermissions(bob, defaultGroup, 1, 200, false, {
            from: contractAdmin
        })
    })

    it('cannot receive tokens by default even in default group 0', async () => {
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

    it('can safeApprove an account with allowanceAndNonce checks', async () => {
        let allowanceAndNonce = await token.allowanceAndNonce(bob, {
            from: alice
        })
        assert.equal(allowanceAndNonce[0], 0)
        assert.equal(allowanceAndNonce[1], 0)
        let tx = await token.safeApprove(bob, 20, allowanceAndNonce[0], allowanceAndNonce[1], {
            from: alice
        })

        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value, 20)
            return true
        })

        let allowanceAndNonce2 = await token.allowanceAndNonce(bob, {
            from: alice
        })
        assert.equal(allowanceAndNonce2[0], 20)
        assert.equal(allowanceAndNonce2[1], 1)

        await token.transferFrom(alice, bob, 9, {
            from: bob
        })

        assert.equal(await token.balanceOf.call(bob), 9)
        assert.equal(await token.balanceOf.call(alice), 91)
    })

    it('cannot safeApprove with the wrong nonce', async () => {
        await token.safeApprove(bob, 20, 0, 0, {
            from: alice
        })
        await truffleAssert.reverts(token.safeApprove(bob, 20, 20, 0, {
            from: alice
        }), "The nonce does not match the current transfer approval nonce")
    })

    it('cannot safeApprove with the wrong expected approval amount', async () => {
        await token.safeApprove(bob, 20, 0, 0, {
            from: alice
        })
        
        await token.transferFrom(alice, bob, 9, {
            from: bob
        })

        await truffleAssert.reverts(token.safeApprove(bob, 20, 20, 1, {
            from: alice
        }), "The expected approved amount does not match the actual approved amount")
    })

    it('cannot transfer more tokens than you have', async () => {
        await truffleAssert.reverts(token.transfer(bob, 101, {from: alice}), "Insufficent tokens")
    })

    it('cannot transfer more tokens than the account you are transferring from has', async () => {
        assert.equal(await token.balanceOf.call(alice), 100)
        await token.safeApprove(bob, 150, 0, 0, {
            from: alice
        })

        await truffleAssert.reverts(token.transferFrom(alice, bob, 101, {
            from: bob
        }), "Insufficent tokens")
        assert.equal(await token.balanceOf.call(alice), 100)
    })
})
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

        await token.setAccountPermissions(bob, defaultGroup, 1, 100, false, {
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
        let tx = await token.approve(bob, 20, {from: alice})
        
        truffleAssert.eventEmitted(tx, 'Approval', (ev) => {
            assert.equal(ev.owner, alice)
            assert.equal(ev.spender, bob)
            assert.equal(ev.value, 20)
            return true
        })

        assert.equal(await token.allowance.call(alice, bob), 20)
        assert.equal(await token.balanceOf.call(bob), 0)
        assert.equal(await token.balanceOf.call(alice), 100)

        await token.transferFrom(alice, bob, 20, {from: bob})

        assert.equal(await token.balanceOf.call(bob), 20)
        assert.equal(await token.balanceOf.call(alice), 80)
    })
})
const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");
// var blaster = require('token-blaster')

class TokenBlaster {
    
    constructor(token, tokenAddress, walletAddress) {
        this.token = token
        this.tokenAddress = tokenAddress
        this.walletAddress = walletAddress
    }

    static async init(tokenAddress, walletAddress) {
        let token = await RestrictedToken.at(tokenAddress)
        return new TokenBlaster(token, tokenAddress, walletAddress)
    }

    async transfer(recipientAddress, amount) {
        return await this.token.transfer(recipientAddress, amount, {from: this.walletAddress})
    }
}

contract("TokenBlaster", function (accounts) {
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
        token = await RestrictedToken.new(rules.address, contractAdmin, contractAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6)

        await token.grantTransferAdmin(contractAdmin, {
            from: contractAdmin
        })

        await token.setAllowGroupTransfer(defaultGroup, defaultGroup, 1, {
            from: contractAdmin
        })

        await token.setAddressPermissions(bob, defaultGroup, 1, 200, false, {
            from: contractAdmin
        })
    })

    it('can do a simple transfer', async () => {
        let blaster = await TokenBlaster.init(token.address, contractAdmin)
        let tx = await blaster.transfer(bob, 50)
        assert.equal(await token.balanceOf.call(bob), 50)

        truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
            assert.equal(ev.from, contractAdmin)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 50)
            return true
        })
    })
})
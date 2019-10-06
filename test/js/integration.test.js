const truffleAssert = require('truffle-assertions');
var RestrictedToken = artifacts.require("RestrictedToken");
var TransferRules = artifacts.require("TransferRules");

contract("Integrated Scenarios", function (accounts) {
    var contractAdmin
    var reserveAdmin
    var transferAdmin
    var exchangeOmnibus
    var foreignInvestorS
    var foreignInvestorS2

    var groupDefault
    var groupReserve
    var groupExchange
    var groupForeignS
    var token


    beforeEach(async function () {
        contractAdmin = accounts[0]
        reserveAdmin = accounts[1]
        transferAdmin = accounts[2]
        exchangeOmnibus = accounts[3]
        foreignInvestorS = accounts[4]
        foreignInvestorS2 = accounts[5]

        groupDefault = 0
        groupReserve = 1
        groupExchange = 2
        groupForeignS = 3

        let rules = await TransferRules.new()
        token = await RestrictedToken.new(rules.address, contractAdmin, reserveAdmin, "xyz", "Ex Why Zee", 6, 100, 1e6)

        // configure initial transferAdmin
        await token.grantTransferAdmin(transferAdmin, {
            from: contractAdmin
        })
    })

    it('initial setup after migrations', async () => {
        let migratedToken = await RestrictedToken.deployed()
        assert.equal(await migratedToken.totalSupply(), 100e6)
        assert.equal(await migratedToken.decimals(), 0)
        assert.equal(await migratedToken.balanceOf(contractAdmin), 0, 'allocates no balance to the contractAdmin')
        assert.equal(await migratedToken.balanceOf(reserveAdmin), 100e6, 'allocates all tokens to the reserve admin')
    })

    it('can be setup correctly for Exchange and Reg S transfer restrictions with separate admin roles', async () => {
        // setup initial transfers groups
        // reserve account can transfer to anyone right away
        await token.setAllowGroupTransfer(groupReserve, groupExchange, 1, {
            from: transferAdmin
        })

        await token.setAllowGroupTransfer(groupReserve, groupForeignS, 1, {
            from: transferAdmin
        })
        await token.setAddressPermissions(reserveAdmin, groupReserve, 1, 100, false, {
            from: transferAdmin
        })

        // // exchange allows Reg S to withdraw to their own accounts
        await token.setAllowGroupTransfer(groupExchange, groupForeignS, 1, {
            from: transferAdmin
        })
        await token.setAddressPermissions(exchangeOmnibus, groupExchange, 1, 100, false, {
            from: transferAdmin
        })

        // // foreign Reg S can deposit into exchange accounts for trading on exchanges
        await token.setAllowGroupTransfer(groupForeignS, groupExchange, 1, {
            from: transferAdmin
        })
        await token.setAddressPermissions(foreignInvestorS, groupForeignS, 1, 10, false, {
            from: transferAdmin
        })

        // // distribute tokens to the exchange for regulated token sale
        await token.transfer(exchangeOmnibus, 50, {
            from: reserveAdmin
        })
        assert.equal(await token.balanceOf.call(exchangeOmnibus), 50)

        await token.transfer(foreignInvestorS, 3, {
            from: exchangeOmnibus
        })
        assert.equal(await token.balanceOf.call(exchangeOmnibus), 47)
        assert.equal(await token.balanceOf.call(foreignInvestorS), 3)

        // Reg S can transfer back to the exchange
        await token.setAllowGroupTransfer(groupForeignS, groupExchange, 1, {
            from: transferAdmin
        })

        await token.transfer(exchangeOmnibus, 1, {
            from: foreignInvestorS
        })

        await token.transfer(exchangeOmnibus, 1, { from: foreignInvestorS })
        
        // Reg S cannot transfer to another Reg S
        await token.setAddressPermissions(foreignInvestorS2, groupForeignS, 1, 10, false, {
            from: transferAdmin
        })
        await truffleAssert.reverts(token.transfer(foreignInvestorS2, 1, {
            from: foreignInvestorS
        }), "TRANSFER GROUP NOT APPROVED")
    })
})


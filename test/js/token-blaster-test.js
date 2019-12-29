const truffleAssert = require('truffle-assertions');
const RestrictedToken = artifacts.require("RestrictedToken");
const TransferRules = artifacts.require("TransferRules");
const TokenBlaster = require('../../src/token-blaster.js')

contract("TokenBlaster", function (accounts) {
    var sendWallet
    var alice
    var bob
    var token
    var blaster

    beforeEach(async function () {
        sendWallet = accounts[0]
        alice = accounts[1]
        bob = accounts[2]
        charlie = accounts[3]

        defaultGroup = 0

        let rules = await TransferRules.new()
        token = await RestrictedToken.new(rules.address, sendWallet, sendWallet, "xyz", "Ex Why Zee", 6, 1e6, 1e6)

        await token.grantTransferAdmin(sendWallet, {
            from: sendWallet
        })

        await token.setAllowGroupTransfer(defaultGroup, defaultGroup, 1, {
            from: sendWallet
        })

        await token.setAllowGroupTransfer(defaultGroup, 1, 1, {
            from: sendWallet
        })

        await token.setAddressPermissions(bob, defaultGroup, 1, 200, false, {
            from: sendWallet
        })

        blaster = await TokenBlaster.init(token.address, sendWallet, web3)

    })

    it('.run', async () => {
        await blaster.run('./test/test_data/test-transfers.csv')
        assert.equal(await token.balanceOf.call('0x57ea4caa7c61c2f48ce26cd5149ee641a75f5f6f'), 150)
    })

    it('can do a simple transfer', async () => {
        let tx = await blaster.transfer(bob, 50)
        assert.equal(await token.balanceOf.call(bob), 50)

        truffleAssert.eventEmitted(tx, 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 50)
            return true
        })
    })
    describe('#setAddressPermissionsAndTransfer', () => {
        it('does not transfer if there is invalid transfer data', async () => {
            let txns = await blaster.setAddressPermissionsAndTransfer({
                address: alice,
            })
            
            assert.equal(await token.balanceOf.call(alice), 0)
            assert.equal(await token.getTransferGroup(alice), 0)
            assert.equal(await token.getFrozenStatus(alice), false)
            assert.equal(await token.getMaxBalance(alice), 0)
            assert.equal(await token.getLockUntil(alice), 0)

        })

        it('can do a transfer and set the transfer group of the recipient address', async () => {
            let txns = await blaster.setAddressPermissionsAndTransfer({
                address: bob,
                amount: '50',
                groupID: '1',
                frozen: 'false',
                maxBalance: "10000",
                timeLockUntil: "0",
            })
            
            assert.equal(await token.balanceOf.call(bob), 50)
            assert.equal(await token.getTransferGroup(bob), 1)
            assert.equal(await token.getFrozenStatus(bob), false)
            assert.equal(await token.getMaxBalance(bob), 10000)
            assert.equal(await token.getLockUntil(bob), 0)
            
            truffleAssert.eventEmitted(txns[0], 'AddressTransferGroup', (ev) => {
                assert.equal(ev.admin, sendWallet)
                assert.equal(ev.addr, bob)
                assert.equal(ev.value, 1)
                return true
            })
            
            truffleAssert.eventEmitted(txns[0], 'AddressMaxBalance', (ev) => {
                assert.equal(ev.admin, sendWallet)
                assert.equal(ev.addr, bob)
                assert.equal(ev.value, 10000)
                return true
            })
            
            truffleAssert.eventEmitted(txns[0], 'AddressTimeLock', (ev) => {
                assert.equal(ev.admin, sendWallet)
                assert.equal(ev.addr, bob)
                assert.equal(ev.value, 0)
                return true
            })
            
            truffleAssert.eventEmitted(txns[0], 'AddressTransferGroup', (ev) => {
                assert.equal(ev.admin, sendWallet)
                assert.equal(ev.addr, bob)
                assert.equal(ev.value, 1)
                return true
            })
            
            truffleAssert.eventEmitted(txns[1], 'Transfer', (ev) => {
                assert.equal(ev.from, sendWallet)
                assert.equal(ev.to, bob)
                assert.equal(ev.value, 50)
                return true
            })
        })
    })

    it('#multiTransfer can transfer to tow recipients', async () => {
        let txns = await blaster.multiTransfer([
            [bob, 23],
            [bob, 27]
        ])
        assert.equal(await token.balanceOf.call(bob), 50)

        truffleAssert.eventEmitted(txns[0], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 23)
            return true
        })

        truffleAssert.eventEmitted(txns[1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 27)
            return true
        })
    })

    it('#multiSetAddressPermissionsAndTransfer can process 2 transfers', async () => {
        let txns = await blaster.multiSetAddressPermissionsAndTransfer([{
                address: bob,
                amount: '23',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                groupID: '1'
            },
            {
                address: alice,
                amount: '19',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                groupID: '1'
            }
        ])
        assert.equal(await token.balanceOf.call(bob), 23)

        truffleAssert.eventEmitted(txns[0][0], 'AddressTransferGroup', (ev) => {
            assert.equal(ev.admin, sendWallet)
            assert.equal(ev.addr, bob)
            assert.equal(ev.value, 1)
            return true
        })

        truffleAssert.eventEmitted(txns[0][1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, bob)
            assert.equal(ev.value, 23)
            return true
        })
        truffleAssert.eventEmitted(txns[1][0], 'AddressTransferGroup', (ev) => {
            assert.equal(ev.admin, sendWallet)
            assert.equal(ev.addr, alice)
            assert.equal(ev.value, 1)
            return true
        })

        truffleAssert.eventEmitted(txns[1][1], 'Transfer', (ev) => {
            assert.equal(ev.from, sendWallet)
            assert.equal(ev.to, alice)
            assert.equal(ev.value, 19)
            return true
        })
    })

    it('.parseTransfers can parse a csv file in preparation for transfers', async () => {
        let transfers = await blaster.getAddressPermissionsAndTransfersFromCSV('./test/test_data/test-transfers.csv')
        assert.deepEqual(transfers, [{
                address: '0x57ea4caa7c61c2f48ce26cd5149ee641a75f5f6f',
                amount: '150',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                groupID: '1'
            },
            {
                address: '0x45d245d054a9cab4c8e74dc131c289207db1ace4',
                amount: '999',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                groupID: '1'
            }
        ])
    })

    describe('#validateAddressPermissionAndTransfer', () => {
        it('should check for required attributes', () => {
            let input = {}
            let results = blaster.validateAddressPermissionAndTransfer(input)
            let requiredFields = []
            
            results.forEach(result => {
                if(result.keyword == 'required') requiredFields.push(result.params.missingProperty)
            })
            assert.sameMembers(requiredFields, ['address', 'amount', 'groupID', 'timeLockUntil', 'frozen','maxBalance'])
        })

        it('should have no errors for valid object', () => {
            let input = {
                address: bob,
                amount: '23',
                frozen: "false",
                maxBalance: "10000",
                timeLockUntil: "0",
                groupID: '1'
            }
            let results = blaster.validateAddressPermissionAndTransfer(input)
            assert.deepEqual(results, null)
        })
    })
})
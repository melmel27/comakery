const RestrictedToken = artifacts.require("RestrictedToken")
const csv = require('csvtojson')

async function init(tokenAddress, walletAddress) {
    let token = await RestrictedToken.at(tokenAddress)
    return new TokenBlaster(token, tokenAddress, walletAddress)
}

class TokenBlaster {
    constructor(token, tokenAddress, walletAddress) {
        this.token = token
        this.tokenAddress = tokenAddress
        this.walletAddress = walletAddress
        this.pendingTransfers = []
        this.transfer = this.transfer.bind(this)
        this.setGroupAndTransfer = this.setGroupAndTransfer.bind(this)
    }

    async getTransfers(csvFilePath) {
        this.pendingTransfers = await csv().fromFile(csvFilePath);
    }

    async transfer(recipientAddress, amount) {
        return await this.token.transfer(recipientAddress, amount, {
            from: this.walletAddress
        })
    }

    async setGroupAndTransfer(transfer) {
        let txn0 = await this.token.setAddressPermissions(
            transfer.address, transfer.transferGroupId, transfer.timeLockUntil, transfer.maxBalance, transfer.frozen)
        let txn1 = await this.token.transfer(transfer.address, transfer.amount)
        return [txn0, txn1]
    }

    async multiTransfer(recipientAddressAndAmountArray) {
        let promises = recipientAddressAndAmountArray.map(([recipientAddress, amount]) => {
            return this.transfer(recipientAddress, amount)
        })
        return Promise.all(promises)
    }

    async multiSetGroupAndTransfer(transfers) {
        let promises = transfers.map((transfer) => {
            return this.setGroupAndTransfer(transfer)
        })
        return Promise.all(promises)
    }
}

exports.init = init
const RestrictedToken = artifacts.require("RestrictedToken")

async function init(tokenAddress, walletAddress) {
    let token = await RestrictedToken.at(tokenAddress)
    return new TokenBlaster(token, tokenAddress, walletAddress)
}

class TokenBlaster {
    constructor(token, tokenAddress, walletAddress) {
        this.token = token
        this.tokenAddress = tokenAddress
        this.walletAddress = walletAddress
        this.transfer = this.transfer.bind(this)
    }

    async transfer(recipientAddress, amount) {
        return await this.token.transfer(recipientAddress, amount, {
            from: this.walletAddress
        })
    }

    async multiTransfer(recipientAddressAndAmountArray) {
        let promises = recipientAddressAndAmountArray.map(([recipientAddress, amount]) => {
            return this.transfer(recipientAddress, amount)
        })
        return Promise.all(promises)
    }
}

exports.init = init
const restrictedTokenBuild = require('../build/contracts/RestrictedToken.json')
const contract = require('truffle-contract')
const RestrictedToken = contract(restrictedTokenBuild)
const {boolean} = require('boolean')
const Ajv = require('ajv')
const util = require('util')

const csv = require('csvtojson')
const autoBind = require('auto-bind')

async function init(tokenAddress, walletAddress, web3) {
    web3.eth.defaultAccount = walletAddress
    web3.eth.personal.unlockAccount(walletAddress)
    RestrictedToken.setProvider(web3.currentProvider) 
    RestrictedToken.defaults({from: walletAddress})
    let token = await RestrictedToken.at(tokenAddress)
    return new TokenBlaster(token, tokenAddress)
}

async function validateCSV(csvPath) {
    let blaster = new TokenBlaster(null, null)
    let permissionsAndTransfers = await blaster.getAddressPermissionsAndTransfersFromCSV(csvPath)
    let validationErrors = blaster.multiValidateAddressPermissionAndTransferData(permissionsAndTransfers)
    return validationErrors
}

class TokenBlaster {
    constructor(token, tokenAddress, walletAddress) {
        this.token = token
        this.tokenAddress = tokenAddress
        this.walletAddress = walletAddress
        autoBind(this)
    }

    async run(csvFilePath) {
        let transfers = await this.getAddressPermissionsAndTransfersFromCSV(csvFilePath)
        let validationErrors = this.multiValidateAddressPermissionAndTransferData(transfers)
        if(validationErrors.length > 0) {
            let report = util.inspect(validationErrors, false, null, false)
            throw new Error(
                "Error: Invalid CSV file. Transfers not initiated. Validation Errors:\n" +
                report +
                "\n\nError: Invalid CSV file. Transfers not initiated."
                )
        }
        let txns = await this.multiSetAddressPermissionsAndTransfer(transfers)
        return txns
    }

    async transfer(recipientAddress, amount) {
        return await this.token.transfer(recipientAddress, amount)
    }

    async multiTransfer(recipientAddressAndAmountArray) {
        let promises = recipientAddressAndAmountArray.map(([recipientAddress, amount]) => {
            return this.transfer(recipientAddress, amount)
        })
        return Promise.all(promises)
    }

    async setAddressPermissionsAndTransfer(transfer) {
        let validationResult = this.validateAddressPermissionAndTransferData(transfer)
        let txn0 = null, txn1 = null
        if(validationResult === null) {   
            txn0 = await this.token.setAddressPermissions(
            transfer.address, 
            transfer.groupID,
            transfer.timeLockUntil,
            transfer.maxBalance,
            boolean(transfer.frozen))

            txn1 = await this.token.transfer(transfer.address, transfer.amount)
        }
        return [txn0, txn1]
    }

    async multiSetAddressPermissionsAndTransfer(transfers) {
        let promises = transfers.map((transfer) => {
            return this.setAddressPermissionsAndTransfer(transfer)
        })
        return Promise.all(promises)
    }

    async getAddressPermissionsAndTransfersFromCSV(csvFilePath) {
        return await csv().fromFile(csvFilePath);
    }

    validateAddressPermissionAndTransferData(jsonTransfer) {
        let ajv = new Ajv({ allErrors: true})
        let schema = {
            type: 'object',
            additionalProperties: false,
            required: ['transferID','email','address', 'amount', 'groupID', 'timeLockUntil', 'maxBalance', 'frozen'],
            properties: {
                transferID: {type: 'string'},
                email: {type: 'string'},
                address: {type: 'string'},
                amount: {type: 'string'},
                frozen: {type: 'string'},
                maxBalance: {type: 'string'},
                timeLockUntil: {type: 'string'},
                groupID: {type: 'string'}
            }
        }

        let validator = ajv.compile(schema)
        validator(jsonTransfer)
        return validator.errors
    }

    multiValidateAddressPermissionAndTransferData(transfers) {
        let badTransfers = []
        transfers.forEach((transfer) => {
            let validationErrors = this.validateAddressPermissionAndTransferData(transfer)
            if(validationErrors !== null) {
                badTransfers.push({ 
                    data: transfer, errors: validationErrors
                 })
            }
        })
        return badTransfers
    }
}

exports.init = init
exports.validateCSV = validateCSV
const restrictedTokenBuild = require('../build/contracts/RestrictedToken.json')
const contract = require('truffle-contract')
const RestrictedToken = contract(restrictedTokenBuild)
const {boolean} = require('boolean')
const Ajv = require('ajv')
const util = require('util')

const csv = require('csvtojson')
const autoBind = require('auto-bind')

const log4js = require('log4js')

async function init(tokenAddress, walletAddress, web3) {
    web3.eth.defaultAccount = walletAddress
    web3.eth.personal.unlockAccount(walletAddress)
    RestrictedToken.setProvider(web3.currentProvider) 
    
    RestrictedToken.defaults({
            from: walletAddress,   
            gas: 6700000, 
            gasPrice: 20000000000
    })

    let networkType = await web3.eth.net.getNetworkType()
    let networkID = await web3.eth.net.getId()
    log4js.configure({
        appenders: {
          everything: { type: 'dateFile', filename: `logs/token-blaster-${networkType}-${networkID}.log` }
        },
        categories: {
          default: { appenders: [ 'everything' ], level: 'debug' }
        }
      })
    
    let token = await RestrictedToken.at(tokenAddress)
    let blaster = await new TokenBlaster(token, tokenAddress)
    return blaster
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
        this.log = log4js.getLogger()
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
        
        this.log.info(
            `setAddresPermission\t${transfer.address}\t${transfer.groupID}\t` +
            `${transfer.timeLockUntil}\t${transfer.maxBalance}\t${transfer.frozen}`
            )
            
        if(validationResult === null) {   
            txn0 = await this.token.setAddressPermissions(
            transfer.address, 
            transfer.groupID,
            transfer.timeLockUntil,
            transfer.maxBalance,
            boolean(transfer.frozen))


            // let restriction = this.token.detectTransferRestriction(this.walletAddress, transfer.address, transfer.amount)
            // console.log("Restriction:", restriction)
            
            this.log.info(`transfer\t${transfer.transferID}\t${transfer.address}\t${transfer.amount}`)
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

    // async multiSetAddressPermissionsAndConfirm(transfers) {
    //     let promises = transfers.map((transfer) => {
    //         return this.setAddressPermissionsAndTransfer(transfer)
    //     })
    //     return Promise.all(promises)
    // }

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
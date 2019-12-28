// 'use strict';
const yargs =  require('yargs')
const argv = yargs
    .command('blaster', 'assign blackchain address permissions and transfer tokens from csv file data', () =>{})
    .option('tokenAddress',{
        alias: 't',
        description: 'token address to send the tokens from',
        type: 'string',
        demand: 'ERROR: You must specify the address of the token'
    })
    // .option('senderAddress',{
    //     alias: 's',
    //     description: 'blockchain address of the sender',
    //     type: 'string',
    //     demand: 'ERROR: You must specify the address sending the tokens' 
    // })
    .option('csv',{
        alias: 'c',
        description: 'private key of the sender',
        type: 'string',
        demand: 'ERROR: You must specify the path of the csv file with token transfers and address permissions' 
    })
    .help('help')
    .usage('Usage: $0 --tokenAddress [address] --senderAddress [blockchain private key] --csv [path]')
    .argv

// module.exports = (sender) => {
//     console.log(this)
//     console.log(argv.tokenAddress)
//     console.log(argv.csv)
//     console.log(this.web3)
//     var TokenBlaster = require('../src/token-blaster.js')
//     var blaster = TokenBlaster.init(argv.tokenAddress)
//     console.log(blaster)
//     blaster.run(argv.csv)
// }


// global.artifacts = artifacts;
global.web3 = web3;

async function main(){
    const newtworkType = await web3.eth.net.getNetworkType();
    const networkId = await web3.eth.net.getId();
    let senderWalletAddress = await web3.eth.getCoinbase()
    var TokenBlaster = require('../src/token-blaster.js')

    console.log("network type:"+newtworkType);
    console.log("network id:"+networkId);

    console.log(argv.tokenAddress)
    console.log(argv.csv)
    console.log(senderWalletAddress)

    var blaster = await TokenBlaster.init(argv.tokenAddress, senderWalletAddress, web3)
    let token = blaster.token

    // move to test env setup script
    if(!(await token.checkTransferAdmin(senderWalletAddress))) await token.grantTransferAdmin(senderWalletAddress)
    await token.setAllowGroupTransfer(0, 0, 1)
    await token.setAllowGroupTransfer(0, 1, 1)

    await blaster.run(argv.csv)
}

// For truffle exec
module.exports = function(callback) {
    main().then(() => callback()).catch(err => callback(err))
};
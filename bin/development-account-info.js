'use strict';

global.artifacts = artifacts;
global.web3 = web3;

async function main(){
    const newtworkType = await web3.eth.net.getNetworkType();
    const networkId = await web3.eth.net.getId();
    console.log("network type:"+newtworkType);
    console.log("network id:"+networkId);

    const RestrictedToken = await artifacts.require('RestrictedToken')
    const token = await RestrictedToken.deployed() 
    const sender = await web3.eth.getCoinbase()

    async function info(title, addr) {
       console.log("\n\n", title, '\n',
        addr, '\n',
        'Balance: ', (await token.balanceOf(addr)).toString(), '\n',
        'Transfer Admin:', (await token.checkTransferAdmin(addr)).toString(),
        )
    }

    await info('Sender:', sender)
    // bin/test/test-transfer.csv addresses for dev environment test sends
    await info('Recipient 1:', '0x57ea4caa7c61c2f48ce26cd5149ee641a75f5f6f')
    await info('Recipient 2:', '0x45d245d054a9cab4c8e74dc131c289207db1ace4')
}

// For truffle exec
module.exports = function(callback) {
    main().then(() => callback()).catch(err => callback(err))
};
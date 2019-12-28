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

module.exports = (sender) => {
    console.log(argv.tokenAddress)
    console.log(argv.csv)
    console.log(web3)
    var TokenBlaster = require('../src/token-blaster.js')
    var blaster = TokenBlaster.init(argv.tokenAddress)
    console.log(blaster)
    blaster.run(argv.csv)
}
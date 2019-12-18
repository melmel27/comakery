require('dotenv').config()
const TransferRules = artifacts.require("TransferRules");
const RestrictedToken = artifacts.require("RestrictedToken");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(TransferRules).then(() => {
    return deployer.deploy(RestrictedToken, 
      TransferRules.address, 
      process.env.TOKEN_CONTRACT_ADMIN_ACCOUNT, 
      process.env.TOKEN_RESERVE_ADMIN, 
      process.env.TOKEN_SYMBOL,
      process.env.TOKEN_NAME,
      process.env.TOKEN_DECIMALS,
      process.env.TOKEN_TOTAL_SUPPLY, 
      process.env.TOKEN_MAX_TOTAL_SUPPLY)
  })
};

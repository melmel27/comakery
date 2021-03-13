const TransferRules = artifacts.require("TransferRules");
const RestrictedToken = artifacts.require("RestrictedToken");

module.exports = function (deployer, network, accounts) {
  const token_contract_admin_account = process.env.TOKEN_CONTRACT_ADMIN_ACCOUNT || accounts[0]
  const token_reserve_admin = process.env.TOKEN_RESERVE_ADMIN || accounts[0]
  const token_symbol = process.env.TOKEN_SYMBOL || 'TEST'
  const token_name = process.env.TOKEN_NAME || 'Test Token'
  const token_decimals = process.env.TOKEN_DECIMALS || 18
  const token_total_supply = process.env.TOKEN_TOTAL_SUPPLY || "100000000000000000000000000" // 100 million * 18 decimal places precision
  const token_max_total_supply = process.env.TOKEN_MAX_TOTAL_SUPPLY || token_total_supply

  deployer.deploy(TransferRules).then(() => {
    return deployer.deploy(RestrictedToken,
      TransferRules.address,
      token_contract_admin_account,
      token_reserve_admin,
      token_symbol,
      token_name,
      token_decimals,
      token_total_supply,
      token_max_total_supply)
  })
};
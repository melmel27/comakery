const TransferRules = artifacts.require("TransferRules");
const RestrictedToken = artifacts.require("RestrictedToken");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(TransferRules).then(() => {
    return deployer.deploy(RestrictedToken, TransferRules.address, accounts[0], accounts[0], "XYZ", "Ex Why Zee", 0, 100e6, 100e6)
  })
};

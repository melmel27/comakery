const TransferRules = artifacts.require("TransferRules");
const RestrictedToken = artifacts.require("RestrictedToken");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(TransferRules).then(() => {
    return deployer.deploy(RestrictedToken, TransferRules.address, accounts[0], accounts[1], "XYZ", "Ex Why Zee", 0, 100)
  })
};

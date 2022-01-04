const Dividends = artifacts.require("Dividends");

module.exports = function (deployer) {
  deployer.deploy(Dividends);
};

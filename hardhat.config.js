require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      chainId: 31337
    }
  }
};

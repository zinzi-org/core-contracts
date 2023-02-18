require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");



/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    enabled: true
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
};

require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.5",
  gasReporter: {
    enabled: true,
  },
  networks: {
    test: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: ["0x"],
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  etherscan: {
    apiKey: "XXX"
  }
};


require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.4.18"
      },
      {
        version: "0.5.16"
      },
      {
        version: "0.6.6",
        settings: { }
      }
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  gasReporter: {
    enabled: true,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      gasPrice: 1,
    },
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


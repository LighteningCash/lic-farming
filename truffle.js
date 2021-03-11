require("dotenv").config();
const HDWalletProvider = require('@truffle/hdwallet-provider')

console.log(process.env.INFURA_APIKEY);

module.exports = {
  networks: {
    development: {
      protocol: "http",
      host: "localhost",
      port: 8545,
      gas: 25000000,
      gasPrice: 5e9,
      network_id: "*",
    },
    bsc: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, 'https://bsc-dataseed.binance.org/'),
      network_id: 56,
      gas: 6000000,
      gasPrice: '10000000000',
      // confirmations: 0,
      // timeoutBlocks: 200,
      skipDryRun: true
    },
    bsctestnet: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, 'https://data-seed-prebsc-1-s1.binance.org:8545/'),
      network_id: 97,
      gas: 6000000,
      gasPrice: '80000000000',
      // confirmations: 0,
      // timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  compilers: {
    solc: {
      version: "0.6.12",
      docker: false,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "istanbul",
      },
    },
  }
}

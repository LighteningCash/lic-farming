require("dotenv").config();

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

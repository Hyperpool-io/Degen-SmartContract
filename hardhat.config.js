require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true, // <--- THIS LINE
    },
  },

  networks: {

    // hardhat: {
    //   forking: {
    //     url: "https://mainnet.infura.io/v3/"+process.env.INFURA_KEY,
    //     blockNumber: 72891475
    //   }
    // },
    testnet: {
      url: "https://ethereum-sepolia-rpc.publicnode.com",
      accounts: [process.env.PRIVATE_KEY],
    },
    polygon: {
      url: "https://polygon-bor-rpc.publicnode.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY, // PolygonScan
    },
  },
};

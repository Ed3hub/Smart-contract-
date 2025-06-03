require("@nomicfoundation/hardhat-ignition");
require("@nomicfoundation/hardhat-toolbox");
//require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

console.log("Sepolia URL:", process.env.SEPOLIA_RPC_URL);
console.log("Private Key:", process.env.PRIVATE_KEY);
console.log("Etherscan API Key:", process.env.ETHERSCAN_API_KEY);

module.exports = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
// to read out current eth balance

const { ethers } = require("hardhat");

async function main() {
  const [signer] = await ethers.getSigners();
  const balance = await signer.provider.getBalance(signer.address);

  console.log(`Wallet Address: ${signer.address}`);
  console.log(`Balance: ${ethers.formatEther(balance)} ETH`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
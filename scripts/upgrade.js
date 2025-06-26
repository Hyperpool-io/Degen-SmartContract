const { ethers, upgrades } = require("hardhat");

async function main() {
  const existingProxyAddr = "0x5A0E898233fc15cFeA2995ddD0E62E5ce1d6a127"; // deployed proxy address
  const NewVault = await ethers.getContractFactory("USDCVault"); // updated code!
  const upgraded = await upgrades.upgradeProxy(existingProxyAddr, NewVault);
  await upgraded.waitForDeployment();
  console.log("USDCVault upgraded at proxy address:",await upgraded.getAddress());
  console.log("Implementation address:", await upgrades.erc1967.getImplementationAddress(await upgraded.getAddress()));
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
const { ethers, upgrades } = require("hardhat");

async function main() {
  [admin] = await ethers.getSigners();

  // Deploy tokens
  const USDC = await ethers.getContractFactory("MockUSDC");
  const usdc = await USDC.deploy();
  await usdc.waitForDeployment();

  const Token1 = await ethers.getContractFactory("MockToken1");
  const token1 = await Token1.deploy();
  await token1.waitForDeployment();

  // Deploy MockUniswapV3NFTManager
  const MockV3 = await ethers.getContractFactory("MockUniV3NFTManager");
  const nftManager = await MockV3.deploy();
  await nftManager.waitForDeployment();

  // Deploy Router
  const Router = await ethers.getContractFactory("MockRouter");
  const router = await Router.deploy();
  await router.waitForDeployment();

  // Set router prices
  await router.setPrice(await usdc.getAddress(), await token1.getAddress(), ethers.parseUnits("2", 18));
  await router.setPrice(await token1.getAddress(), await usdc.getAddress(), ethers.parseUnits("0.5", 18));

  // Deploy WalletLogic
  const WalletLogic = await ethers.getContractFactory("WalletLogic");
  const walletLogic = await upgrades.deployProxy(WalletLogic, [admin.address, admin.address], { initializer: "initialize" });
  await walletLogic.waitForDeployment();
  const implAddr = await upgrades.erc1967.getImplementationAddress(await walletLogic.getAddress());

  // Deploy AggregatorManager
  const AggregatorManager = await ethers.getContractFactory("AggregatorManager");
  const aggregatorMgr = await upgrades.deployProxy(
    AggregatorManager,
    [await usdc.getAddress(), implAddr, await nftManager.getAddress(), await router.getAddress()],
    { initializer: "initialize" }
  );
  await aggregatorMgr.waitForDeployment();

  console.log("USDC:", await usdc.getAddress());
  console.log("Token1:", await token1.getAddress());
  console.log("MockUniV3NFTManager:", await nftManager.getAddress());
  console.log("MockRouter:", await router.getAddress());
  console.log("WalletLogic (Proxy):", await walletLogic.getAddress());
  console.log("AggregatorManager (Proxy):", await aggregatorMgr.getAddress());
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
const { ethers, upgrades } = require('hardhat');

async function deployOracleFixture() {
  const OracleContract = await ethers.getContractFactory("Oracle");
  // deployProxy会自动帮忙部署1个透明模式的代理合约，且会自动调用initialize方法
  // 后续升级使用upgradeProxy方法
  const proxy = await upgrades.deployProxy(OracleContract, [], { initializer: "initialize" });
  await proxy.waitForDeployment();
  const address = await proxy.getAddress();
  console.log('Oracle proxy address: ', address);
  const oracleContract = await OracleContract.attach(address);
  return { oracleContract, oracleContractAddress: address};
}
async function deployParamFixture() {
  const ParamContract = await ethers.getContractFactory("Param");
  const proxy = await upgrades.deployProxy(ParamContract, [], { initializer: "initialize" });
  await proxy.waitForDeployment();
  const address = await proxy.getAddress();
  console.log('Param proxy address: ', address);
  const paramContract = await ParamContract.attach(address);
  return { paramContract, paramContractAddress: address};
}
async function deployAdminFixture() {
  const oracleFixture = await loadFixture(deployOracleFixture);
  const paramFixture = await loadFixture(deployParamFixture);
  const AdminContract = await ethers.getContractFactory("Admin");
  const proxy = await upgrades.deployProxy(AdminContract, [
    paramFixture.paramContractAddress,
    oracleFixture.oracleContractAddress,
  ], { initializer: "initialize" });
  await proxy.waitForDeployment();
  const address = await proxy.getAddress();
  console.log('Admin proxy address: ', address);
  const adminContract = await AdminContract.attach(address);
  return { adminContract, adminContractAddress: address };
}
async function deployBettingFixture() {
  const adminFixture = await loadFixture(deployAdminFixture);
  const BettingContract = await ethers.getContractFactory("Betting");
  const proxy = await upgrades.deployProxy(BettingContract, [
    adminFixture.adminContractAddress,
  ], { initializer: "initialize" });
  await proxy.waitForDeployment();
  const address = await proxy.getAddress();
  console.log('Betting proxy address: ', address);
  const bettingContract = await BettingContract.attach(address);
  return { bettingContract };
}

async function main() {
  const { bettingContract } = await loadFixture(deployBettingFixture);
  await bettingContract.waitForDeployment();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

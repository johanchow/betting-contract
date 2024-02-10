import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
const { ethers, upgrades } = require('hardhat');

describe("Betting", function () {
  async function deployOracleFixture() {
    const OracleContract = await ethers.getContractFactory("Oracle");
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
  it('test', async () => {
    const { bettingContract } = await loadFixture(deployBettingFixture);
    const x = await bettingContract.bettingId();
    expect(x).to.equal(1);
  });
});

const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("BaaOracle", function () {
  let baaOracle;
  let owner;
  let addr1;
  let addr2;

  // 模拟 Chainlink 预言机地址
  const mockPriceFeed = "0x1234567890123456789012345678901234567890";
  const mockToken = "0x0987654321098765432109876543210987654321";

  beforeEach(async function () {
    // 获取测试账户
    [owner, addr1, addr2] = await ethers.getSigners();

    // 部署合约
    const BaaOracle = await ethers.getContractFactory("BaaOracle");
    baaOracle = await upgrades.deployProxy(BaaOracle, [], { initializer: 'initialize' });
    await baaOracle.waitForDeployment();
  });

  describe("初始化", function () {
    it("应该正确设置所有者", async function () {
      expect(await baaOracle.owner()).to.equal(owner.address);
    });

    it("应该正确设置初始管理员", async function () {
      expect(await baaOracle.admins(owner.address)).to.be.true;
    });
  });

  describe("价格源管理", function () {
    it("所有者应该能够添加价格源", async function () {
      await expect(baaOracle.addPriceFeed(mockToken, mockPriceFeed))
        .to.emit(baaOracle, "PriceFeedAdded")
        .withArgs(mockToken, mockPriceFeed);

      expect(await baaOracle.priceFeeds(mockToken)).to.equal(mockPriceFeed);
    });

    it("非所有者不能添加价格源", async function () {
      await expect(
        baaOracle.connect(addr1).addPriceFeed(mockToken, mockPriceFeed)
      ).to.be.revertedWithCustomError(baaOracle, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);
    });

    it("所有者应该能够移除价格源", async function () {
      await baaOracle.addPriceFeed(mockToken, mockPriceFeed);

      await expect(baaOracle.removePriceFeed(mockToken))
        .to.emit(baaOracle, "PriceFeedRemoved")
        .withArgs(mockToken);

      expect(await baaOracle.priceFeeds(mockToken)).to.equal(ethers.ZeroAddress);
    });

    it("不能添加零地址作为价格源", async function () {
      await expect(
        baaOracle.addPriceFeed(ethers.ZeroAddress, mockPriceFeed)
      ).to.be.revertedWithCustomError(baaOracle, "InvalidAddress")
        .withArgs("Invalid token address");
    });
  });

  describe("管理员功能", function () {
    it("管理员应该能够添加新管理员", async function () {
      await expect(baaOracle.addAdmins([addr1.address]))
        .to.emit(baaOracle, "AdminAdded")
        .withArgs(addr1.address);

      expect(await baaOracle.admins(addr1.address)).to.be.true;
    });

    it("管理员应该能够批量添加新管理员", async function () {
      await expect(baaOracle.addAdmins([addr1.address, addr2.address]))
        .to.emit(baaOracle, "AdminAdded")
        .withArgs(addr1.address)
        .to.emit(baaOracle, "AdminAdded")
        .withArgs(addr2.address);

      expect(await baaOracle.admins(addr1.address)).to.be.true;
      expect(await baaOracle.admins(addr2.address)).to.be.true;
    });

    it("管理员应该能够移除管理员", async function () {
      // 先添加管理员
      await baaOracle.addAdmins([addr1.address]);

      await expect(baaOracle.removeAdmins([addr1.address]))
        .to.emit(baaOracle, "AdminRemoved")
        .withArgs(addr1.address);

      expect(await baaOracle.admins(addr1.address)).to.be.false;
    });

    it("非管理员不能添加新管理员", async function () {
      await expect(
        baaOracle.connect(addr1).addAdmins([addr2.address])
      ).to.be.revertedWithCustomError(baaOracle, "NotAdmin")
        .withArgs("Only admin can call this function");
    });

    it("不能添加零地址作为管理员", async function () {
      await expect(
        baaOracle.addAdmins([ethers.ZeroAddress])
      ).to.be.revertedWithCustomError(baaOracle, "InvalidAddress")
        .withArgs("Invalid admin address");
    });
  });

  describe("代币状态检查", function () {
    it("应该正确返回未支持的代币状态", async function () {
      expect(await baaOracle.checkTokenStatus(mockToken)).to.equal(2);
    });

    it("应该正确返回已支持的代币状态", async function () {
      await baaOracle.addPriceFeed(mockToken, mockPriceFeed);
      expect(await baaOracle.checkTokenStatus(mockToken)).to.equal(1);
    });
  });
});

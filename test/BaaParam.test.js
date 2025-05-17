const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("BaaParam", function () {
  let baaParam;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    // 获取测试账户
    [owner, addr1, addr2] = await ethers.getSigners();

    // 部署合约
    const BaaParam = await ethers.getContractFactory("BaaParam");
    baaParam = await upgrades.deployProxy(BaaParam, [], { initializer: 'initialize' });
    await baaParam.waitForDeployment();
  });

  describe("初始化", function () {
    it("应该正确设置默认参数", async function () {
      const params = await baaParam.getAllParams();
      expect(params._feeRate).to.equal(50); // 0.5%
      expect(params._minPlaceTime).to.equal(24 * 60 * 60); // 1 day
      expect(params._maxPlaceTime).to.equal(7 * 24 * 60 * 60); // 7 days
      expect(params._minAnswerTime).to.equal(12 * 60 * 60); // 12 hours
      expect(params._maxAnswerTime).to.equal(2 * 24 * 60 * 60); // 2 days
      expect(params._minSettleTime).to.equal(12 * 60 * 60); // 12 hours
      expect(params._maxSettleTime).to.equal(2 * 24 * 60 * 60); // 2 days
      expect(params._minClaimTime).to.equal(24 * 60 * 60); // 1 day
      expect(params._maxClaimTime).to.equal(3 * 24 * 60 * 60); // 3 days
    });

    it("应该默认支持 ETH", async function () {
      expect(await baaParam.supportedTokens(ethers.ZeroAddress)).to.equal(1);
    });
  });

  describe("费率管理", function () {
    it("所有者应该能够更新平台费率", async function () {
      const newRate = 100; // 1%
      await expect(baaParam.updatePlatformFeeRate(newRate))
        .to.emit(baaParam, "PlatformFeeRateUpdated")
        .withArgs(50, newRate);

      expect(await baaParam.platformFeeRate()).to.equal(newRate);
    });

    it("费率不能超过1000（10%）", async function () {
      await expect(baaParam.updatePlatformFeeRate(1001))
        .to.be.revertedWithCustomError(baaParam, "FeeRateTooHigh")
        .withArgs(1001);
    });

    it("非所有者不能更新费率", async function () {
      await expect(
        baaParam.connect(addr1).updatePlatformFeeRate(100)
      ).to.be.revertedWithCustomError(baaParam, "OwnableUnauthorizedAccount")
        .withArgs(addr1.address);
    });
  });

  describe("时间限制管理", function () {
    it("所有者应该能够更新下注时间限制", async function () {
      const newMin = 2 * 24 * 60 * 60; // 2 days
      const newMax = 10 * 24 * 60 * 60; // 10 days

      await expect(baaParam.updatePlaceTimeLimit(newMin, newMax))
        .to.emit(baaParam, "PlaceTimeLimitUpdated")
        .withArgs(24 * 60 * 60, newMin, 7 * 24 * 60 * 60, newMax);

      const params = await baaParam.getAllParams();
      expect(params._minPlaceTime).to.equal(newMin);
      expect(params._maxPlaceTime).to.equal(newMax);
    });

    it("最小时间不能大于最大时间", async function () {
      await expect(
        baaParam.updatePlaceTimeLimit(7 * 24 * 60 * 60, 1 * 24 * 60 * 60)
      ).to.be.revertedWithCustomError(baaParam, "MinValueGreaterThanMax")
        .withArgs(7 * 24 * 60 * 60, 1 * 24 * 60 * 60);
    });

    it("最小时间不能太短", async function () {
      await expect(
        baaParam.updatePlaceTimeLimit(30 * 60, 2 * 24 * 60 * 60) // 30分钟
      ).to.be.revertedWithCustomError(baaParam, "TimeTooShort")
        .withArgs(30 * 60);
    });

    it("最大时间不能太长", async function () {
      await expect(
        baaParam.updatePlaceTimeLimit(1 * 24 * 60 * 60, 31 * 24 * 60 * 60) // 31天
      ).to.be.revertedWithCustomError(baaParam, "TimeTooLong")
        .withArgs(31 * 24 * 60 * 60);
    });
  });

  describe("代币管理", function () {
    const mockTokens = [
      "0x1234567890123456789012345678901234567890",
      "0x0987654321098765432109876543210987654321"
    ];

    it("所有者应该能够批量添加代币", async function () {
      await expect(baaParam.addSupportedTokens(mockTokens))
        .to.emit(baaParam, "TokensBatchAdded")
        .withArgs(mockTokens);

      for (const token of mockTokens) {
        expect(await baaParam.supportedTokens(token)).to.equal(1);
      }
    });

    it("所有者应该能够批量移除代币", async function () {
      await baaParam.addSupportedTokens(mockTokens);

      await expect(baaParam.removeSupportedTokens(mockTokens))
        .to.emit(baaParam, "TokensBatchRemoved");

      for (const token of mockTokens) {
        expect(await baaParam.supportedTokens(token)).to.equal(0);
      }
    });
  });

  describe("时间验证", function () {
    it("应该正确验证下注时间", async function () {
      const params = await baaParam.getAllParams();
      const minTime = BigInt(params._minPlaceTime);
      const maxTime = BigInt(params._maxPlaceTime);

      expect(await baaParam.validatePlaceTime(minTime)).to.be.true;
      expect(await baaParam.validatePlaceTime(maxTime)).to.be.true;
      expect(await baaParam.validatePlaceTime(minTime - 1n)).to.be.false;
      expect(await baaParam.validatePlaceTime(maxTime + 1n)).to.be.false;
    });
  });

  describe("手续费计算", function () {
    it("应该正确计算手续费", async function () {
      const amount = ethers.parseEther("1.0"); // 1 ETH
      const fee = await baaParam.calculateFee(amount);
      expect(fee).to.equal(amount * 50n / 10000n); // 0.5% of 1 ETH
    });
  });
});

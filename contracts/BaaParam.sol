// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BaaParam is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 费率参数（以基点为单位，1个基点 = 0.01%）
    uint256 public feeRate;           // 基础费率
    uint256 public minBetAmount;      // 最小下注金额
    uint256 public maxBetAmount;      // 最大下注金额
    uint256 public minPredictionTime; // 最小预测时间（秒）
    uint256 public maxPredictionTime; // 最大预测时间（秒）

    // 事件
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event BetAmountLimitsUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);
    event PredictionTimeLimitsUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);

    error InvalidAmount(string message);
    error InvalidTime(string message);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        // 初始化 UUPS 升级机制
        __UUPSUpgradeable_init();
        // 设置初始合约所有者 (msg.sender)，启用 onlyOwner 权限控制
        __Ownable_init(msg.sender);

        // 设置默认值
        feeRate = 500;           // 5%
        minBetAmount = 0.01 ether;
        maxBetAmount = 100 ether;
        minPredictionTime = 1 hours;
        maxPredictionTime = 7 days;
    }

    // UUPS升级授权
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 更新费率
    function updateFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, InvalidAmount("Fee rate too high")); // 最高10%
        uint256 oldRate = feeRate;
        feeRate = newRate;
        emit FeeRateUpdated(oldRate, newRate);
    }

    // 更新下注金额限制
    function updateBetAmountLimits(uint256 newMin, uint256 newMax) external onlyOwner {
        require(newMin < newMax, InvalidAmount("Min amount must less then max"));
        require(newMin > 0, InvalidAmount("Min amount must be positive"));

        uint256 oldMin = minBetAmount;
        uint256 oldMax = maxBetAmount;

        minBetAmount = newMin;
        maxBetAmount = newMax;

        emit BetAmountLimitsUpdated(oldMin, newMin, oldMax, newMax);
    }

    // 更新预测时间限制
    function updatePredictionTimeLimits(uint256 newMin, uint256 newMax) external onlyOwner {
        require(newMin < newMax, InvalidTime("Invalid limits"));
        require(newMin >= 1 hours, InvalidTime("Min time too short"));
        require(newMax <= 30 days, InvalidTime("Max time too long"));

        uint256 oldMin = minPredictionTime;
        uint256 oldMax = maxPredictionTime;

        minPredictionTime = newMin;
        maxPredictionTime = newMax;

        emit PredictionTimeLimitsUpdated(oldMin, newMin, oldMax, newMax);
    }

    // 获取所有参数
    function getAllParams() external view returns (
        uint256 _feeRate,
        uint256 _minBetAmount,
        uint256 _maxBetAmount,
        uint256 _minPredictionTime,
        uint256 _maxPredictionTime
    ) {
        return (
            feeRate,
            minBetAmount,
            maxBetAmount,
            minPredictionTime,
            maxPredictionTime
        );
    }

    // 验证下注金额是否在限制范围内
    function validateBetAmount(uint256 amount) external view returns (bool) {
        return amount >= minBetAmount && amount <= maxBetAmount;
    }

    // 验证预测时间是否在限制范围内
    function validatePredictionTime(uint256 duration) external view returns (bool) {
        return duration >= minPredictionTime && duration <= maxPredictionTime;
    }

    // 计算手续费
    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * feeRate) / 10000; // 使用基点计算
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BaaParam is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 费率参数（以基点为单位，1个基点 = 0.01%）
    uint8   public platformFeeRate;   // 平台基础费率
    uint256 public minPlaceTime;      // 最小预测时间（秒）
    uint256 public maxPlaceTime;      // 最大预测时间（秒）
    uint256 public minAnswerTime;     // 最小确认答案时间
    uint256 public maxAnswerTime;     // 最大确认答案时间
    uint256 public minSettleTime;     // 最小结算时间
    uint256 public maxSettleTime;     // 最大结算时间
    uint256 public minClaimTime;      // 最小领奖时间
    uint256 public maxClaimTime;      // 最大领奖时间
    mapping (address => uint8) public supportedTokens;   // 支持使用的token列表;

    // 事件
    event PlatformFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event BetAmountLimitsUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);
    event PlaceTimeLimitUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);
    event AnswerTimeLimitUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);
    event SettleTimeLimitUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);
    event ClaimTimeLimitUpdated(uint256 oldMin, uint256 newMin, uint256 oldMax, uint256 newMax);
    event TokensBatchAdded(address[] tokens);
    event TokensBatchRemoved(address[] indexed tokens);

    error InvalidAmount(string message);
    error InvalidTime(string message);
    error InvalidToken(string message);

    modifier timeValid(uint256 minValue, uint256 maxValue) {
        require(minValue < maxValue, "Min value should be less than max value");
        require(minValue >= 1 hours, "Min time too short");
        require(maxValue <= 30 days, "Max time too long");
        _;
    }

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
        platformFeeRate = 50;           // 0.5%
        minPlaceTime = 1 days;
        maxPlaceTime = 7 days;
        minAnswerTime = 12 hours;
        maxAnswerTime = 2 days;
        minSettleTime = 12 hours;
        maxSettleTime = 2 days;
        minClaimTime = 1 days;
        maxClaimTime = 3 days;

        // ETH
        supportedTokens[address(0)] = 1;
    }

    // UUPS升级授权
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 更新费率
    function updatePlatformFeeRate(uint8 newRate) external onlyOwner {
        require(newRate <= 1000, InvalidAmount("Fee rate too high")); // 最高10%
        uint8 oldRate = platformFeeRate;
        platformFeeRate = newRate;
        emit PlatformFeeRateUpdated(oldRate, newRate);
    }

    // 更新下注时间限制
    function updatePlaceTimeLimit(uint256 newMin, uint256 newMax) external onlyOwner timeValid(newMin, newMax) {
        uint256 oldMin = minPlaceTime;
        uint256 oldMax = maxPlaceTime;

        minPlaceTime = newMin;
        maxPlaceTime = newMax;

        emit PlaceTimeLimitUpdated(oldMin, newMin, oldMax, newMax);
    }

    // 更新确认答案时间限制
    function updateAnswerTimeLimit(uint256 newMin, uint256 newMax) external onlyOwner timeValid(newMin, newMax) {
        uint256 oldMin = minAnswerTime;
        uint256 oldMax = maxAnswerTime;

        minAnswerTime = newMin;
        maxAnswerTime = newMax;

        emit AnswerTimeLimitUpdated(oldMin, newMin, oldMax, newMax);
    }

    // 更新结算时间限制
    function updateSettleTimeLimit(uint256 newMin, uint256 newMax) external onlyOwner timeValid(newMin, newMax) {
        uint256 oldMin = minSettleTime;
        uint256 oldMax = maxSettleTime;

        minSettleTime = newMin;
        maxSettleTime = newMax;

        emit SettleTimeLimitUpdated(oldMin, newMin, oldMax, newMax);
    }

    // 更新领奖时间限制
    function updateClaimTimeLimit(uint256 newMin, uint256 newMax) external onlyOwner timeValid(newMin, newMax) {
        uint256 oldMin = minClaimTime;
        uint256 oldMax = maxClaimTime;

        minClaimTime = newMin;
        maxClaimTime = newMax;

        emit ClaimTimeLimitUpdated(oldMin, newMin, oldMax, newMax);
    }

    function addSupportedTokens(address[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            supportedTokens[tokens[i]] = 1;
        }
        emit TokensBatchAdded(tokens);
    }

    function removeSupportedTokens(address[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            supportedTokens[tokens[i]] = 0;
        }
        emit TokensBatchRemoved(tokens);
    }

    // 获取所有参数
    function getAllParams() external view returns (
        uint8   _feeRate,
        uint256 _minPlaceTime,
        uint256 _maxPlaceTime,
        uint256 _minAnswerTime,
        uint256 _maxAnswerTime,
        uint256 _minSettleTime,
        uint256 _maxSettleTime,
        uint256 _minClaimTime,
        uint256 _maxClaimTime
    ) {
        return (
            platformFeeRate,
            minPlaceTime,
            maxPlaceTime,
            minAnswerTime,
            maxAnswerTime,
            minSettleTime,
            maxSettleTime,
            minClaimTime,
            maxClaimTime
        );
    }

    // 验证下注时间是否在限制范围内
    function validatePlaceTime(uint256 duration) external view returns (bool) {
        return duration >= minPlaceTime && duration <= maxPlaceTime;
    }

    // 验证确认答案时间是否在限制范围内
    function validateAnswerTime(uint256 duration) external view returns (bool) {
        return duration >= minAnswerTime && duration <= maxAnswerTime;
    }

    // 验证结算时间是否在限制范围内
    function validateSettleTime(uint256 duration) external view returns (bool) {
        return duration >= minSettleTime && duration <= maxSettleTime;
    }

    // 验证领奖时间是否在限制范围内
    function validateClaimTime(uint256 duration) external view returns (bool) {
        return duration >= minClaimTime && duration <= maxClaimTime;
    }

    // 计算手续费
    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * platformFeeRate) / 10000; // 使用基点计算
    }
}

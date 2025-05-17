// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BaaOracle is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 存储代币地址到Chainlink预言机地址的映射
    mapping(address => address) public priceFeeds;

    mapping (address => bool) public admins;

    // 事件
    event PriceFeedAdded(address indexed token, address indexed priceFeed);
    event PriceFeedRemoved(address indexed token);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    error InvalidAddress(string message);
    error NotAdmin(string message);

    modifier onlyAdmin() {
        if (!admins[msg.sender]) revert NotAdmin("Only admin can call this function");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);

        // 设置部署者为管理员
        admins[msg.sender] = true;
    }

    // UUPS升级授权
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 添加价格源
    function addPriceFeed(address token, address priceFeed) external onlyOwner {
        if (token == address(0)) revert InvalidAddress("Invalid token address");
        if (priceFeed == address(0)) revert InvalidAddress("Invalid price feed address");
        priceFeeds[token] = priceFeed;
        emit PriceFeedAdded(token, priceFeed);
    }

    // 移除价格源
    function removePriceFeed(address token) external onlyOwner {
        if (priceFeeds[token] == address(0)) revert InvalidAddress("Price feed not found");
        delete priceFeeds[token];
        emit PriceFeedRemoved(token);
    }

    // 获取最新价格
    function getLatestPrice(address token) external view returns (int256) {
        address priceFeed = priceFeeds[token];
        if (priceFeed == address(0)) revert InvalidAddress("Price feed not found");

        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(priceFeed);

        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeedContract.latestRoundData();

        if (price <= 0) revert InvalidAddress("Invalid price");
        if (timeStamp == 0) revert InvalidAddress("Round not complete");
        if (answeredInRound < roundID) revert InvalidAddress("Stale price");

        return price;
    }

    // 获取价格的小数位数
    function getDecimals(address token) external view returns (uint8) {
        address priceFeed = priceFeeds[token];
        if (priceFeed == address(0)) revert InvalidAddress("Price feed not found");

        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(priceFeed);
        return priceFeedContract.decimals();
    }

    // 获取特定轮次的价格
    function getRoundData(address token, uint80 roundId) external view returns (
        uint80 id,
        int256 price,
        uint256 startedAt,
        uint256 timeStamp,
        uint80 answeredInRound
    ) {
        address priceFeed = priceFeeds[token];
        if (priceFeed == address(0)) revert InvalidAddress("Price feed not found");

        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(priceFeed);
        return priceFeedContract.getRoundData(roundId);
    }

    // 添加管理员
    function addAdmins(address[] calldata newAdmins) external onlyAdmin {
        for (uint i = 0; i < newAdmins.length; i++) {
            if (newAdmins[i] == address(0)) revert InvalidAddress("Invalid admin address");
            admins[newAdmins[i]] = true;
            emit AdminAdded(newAdmins[i]);
        }
    }

    // 移除管理员
    function removeAdmins(address[] calldata adminsToRemove) external onlyAdmin {
        for (uint i = 0; i < adminsToRemove.length; i++) {
            if (adminsToRemove[i] == address(0)) revert InvalidAddress("Invalid admin address");
            admins[adminsToRemove[i]] = false;
            emit AdminRemoved(adminsToRemove[i]);
        }
    }

    // 检查token是否存在: 1、表示已支持  2、表示未支持
    function checkTokenStatus(address token) public view returns (uint8) {
        if (priceFeeds[token] == address(0)) {
            return 2;
        }
        return 1;
    }
}

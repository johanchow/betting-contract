// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BaaOracle is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 存储代币地址到Chainlink预言机地址的映射
    mapping(address => address) public priceFeeds;

     address internal admin;

    // 事件
    event PriceFeedAdded(address indexed token, address indexed priceFeed);
    event PriceFeedRemoved(address indexed token);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
    }

    // UUPS升级授权
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 添加价格源
    function addPriceFeed(address token, address priceFeed) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(priceFeed != address(0), "Invalid price feed address");
        priceFeeds[token] = priceFeed;
        emit PriceFeedAdded(token, priceFeed);
    }

    // 移除价格源
    function removePriceFeed(address token) external onlyOwner {
        require(priceFeeds[token] != address(0), "Price feed not found");
        delete priceFeeds[token];
        emit PriceFeedRemoved(token);
    }

    // 获取最新价格
    function getLatestPrice(address token) external view returns (int256) {
        address priceFeed = priceFeeds[token];
        require(priceFeed != address(0), "Price feed not found");

        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(priceFeed);

        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeedContract.latestRoundData();

        require(price > 0, "Invalid price");
        require(timeStamp > 0, "Round not complete");
        require(answeredInRound >= roundID, "Stale price");

        return price;
    }

    // 获取价格的小数位数
    function getDecimals(address token) external view returns (uint8) {
        address priceFeed = priceFeeds[token];
        require(priceFeed != address(0), "Price feed not found");

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
        require(priceFeed != address(0), "Price feed not found");

        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(priceFeed);
        return priceFeedContract.getRoundData(roundId);
    }

    // 更改管理员
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    // 检查token是否存在: 1、表示已支持  2、表示未支持
    function checkTokenStatus(address token) public view returns (uint8) {
      if (priceFeeds[token] == address(0)) {
        return 2;
      }
      return 1;
    }
}

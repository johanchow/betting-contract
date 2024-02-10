// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// 实现一个竞猜合约，有以下功能：开启竞猜、下注、查看奖池金额、查看自己的投注金额、查看自己的奖金、提取奖金、竞猜时间到期停止竞猜、输入竞猜结果选项
contract Admin is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    address public paramAddress;
    address public oracleAddress;

    function updateParamAddress(address _paramAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paramAddress = _paramAddress;
    }

    function updateOracleAddress(address _oracleAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oracleAddress = _oracleAddress;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function initialize(
        address _paramAddress,
        address _oracleAddress
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        // _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        paramAddress = _paramAddress;
        oracleAddress = _oracleAddress;
    }
}

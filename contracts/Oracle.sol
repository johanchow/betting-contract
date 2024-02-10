// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "hardhat/console.sol";

contract Oracle is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    address[] public allowedTokens;
    mapping(bytes32 => uint128) public aggregators;

    function getAllowedTokens() external view returns(address[] memory) {
        return allowedTokens;
    }

    function getPriceByIndex(address aToken, uint32 _timeAt) external view returns(uint128) {
        return aggregators[keccak256(abi.encodePacked(aToken,_timeAt))];
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function initialize() external initializer {
        console.log("Oracle initialize");
        __AccessControl_init();
        // _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __UUPSUpgradeable_init();
    }
}

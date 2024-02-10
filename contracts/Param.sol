// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Param is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    uint24 public createThreshold;     /// @dev createThreshold * 10 ** 18 ;
    event UpdateCreateThresholdEvent(uint24 newValue);

    function updateCreateThreshold(uint24 _createThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        createThreshold = _createThreshold;
        emit UpdateCreateThresholdEvent(_createThreshold);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function initialize(
    ) external initializer {
        createThreshold = 1000;
    }
}

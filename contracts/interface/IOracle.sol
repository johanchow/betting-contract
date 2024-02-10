// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IOracle {
    function getAllowedTokens() external view returns(address[] memory);
    function getPriceByIndex(address aToken, uint32 _timeAt) external view returns(uint128);
}

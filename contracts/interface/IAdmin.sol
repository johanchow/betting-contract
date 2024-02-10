// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IAdmin {
    function updateParamAddress(address _paramAddress) external;
    function updateOracleAddress(address _oracleAddress) external;
}

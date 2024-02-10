// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IParam {
    function createThreshold() external view returns(uint24);
    function updateCreateThreshold(uint24 _createThreshold) external;
}

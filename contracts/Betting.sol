// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interface/IParam.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// 实现一个竞猜合约，有以下功能：开启竞猜、下注、查看奖池金额、查看自己的投注金额、查看自己的奖金、提取奖金、竞猜时间到期停止竞猜、输入竞猜结果选项
contract Betting is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    // 竞猜的状态
    enum BettingStatus {
        NotStarted,
        Placing,
        Answering,
        Settling,
        Ended
    }

    // 竞猜的信息
    struct BettingInfo {
        address owner;
        uint256 startTime;
        uint256 settleTime;
        uint256 rewardTime;
        uint256 endTime;
        uint256 totalBettingAmount;
        uint256 totalRewardAmount;
        /* 公证人(有权输入结果选项) */
        address[] referees;
        uint8 optionNum;
        uint8 answerOptionIndex;
        BettingStatus status;
    }

    // 下注金额和奖励信息
    struct PlaceInfo {
        address token;
        uint8 optionId;
        uint256 sourceAmount;
        uint256 rewardAmount;
    }

    // 金额信息
    struct MoneyInfo {
        address token;
        uint256 sourceAmount;
        uint256 rewardAmount;
        // uint256 value;
    }

    // 公证人填写的答案
    struct RefereeAnswerInfo {
        address referee;
        uint8 optionId;
    }

    address public adminContract;

    uint256 public bettingId;   // @notice pairIDCounter

    // 竞猜信息字典 bettingId => BettingInfo
    mapping(uint256 => BettingInfo) public bettingInfoMap;

    // 竞猜的用户投注金额 bytes32(bettingId, player, optionId) => MoneyInfo[]
    mapping(bytes32 => MoneyInfo[]) public playerOptionMoneyInfos;

    // 竞猜的选项汇总投注信息 bytes32(bettingId, optionId) => MoneyInfo[]
    mapping(bytes32 => MoneyInfo[]) public summaryOptionMoneyInfos;

    // 竞猜的公证人填写的答案 bettingId => RefereeAnswerInfo
    mapping(uint256 => RefereeAnswerInfo[]) public bettingRefereeAnswerMap;

    error OperationDenied(uint256);

    /**
     * @dev 创建竞猜
     */
    function create(
        uint256 startTime,
        uint256 settleTime,
        uint256 rewardTime,
        uint256 endTime,
        uint8 optionNum,
        address[] calldata referees,
        PlaceInfo[] calldata placeInfos
    ) external {
        address sender = msg.sender;
        require(block.timestamp < settleTime && settleTime < rewardTime && rewardTime < endTime, "invalid time");
        require(optionNum >= 2 && optionNum <= 7, "invalid optionNum");
        uint24 createThreshold = IParam(adminContract).createThreshold();
        bettingInfoMap[bettingId] = BettingInfo({
            owner: sender,
            startTime: startTime,
            settleTime: settleTime,
            rewardTime: rewardTime,
            endTime: endTime,
            referees: referees,
            optionNum: optionNum,
            status: BettingStatus.NotStarted,
            totalBettingAmount: 0,
            totalRewardAmount: 0,
            answerOptionIndex: 0
        });
        _place(bettingId, sender, placeInfos);
    }

    /**
     * @dev 下注
     */
    function place(uint256 bettingId, PlaceInfo[] calldata placeInfos) external {
        _place(bettingId, msg.sender, placeInfos);
    }

    /**
     * @dev 下注的逻辑实现方法
     */
    function _place(uint256 bettingId, address player, PlaceInfo[] calldata placeInfos) internal {
        require(bettingInfoMap[bettingId].status == BettingStatus.Placing, "betting not Placing");
        address sender = msg.sender;
        
        for (uint8 i = 0; i < placeInfos.length; i++) {
            PlaceInfo memory pi = placeInfos[i];
            // 跨链转账
            IERC20Metadata(pi.token).transferFrom(sender, address(this), pi.sourceAmount);
            // 记录用户下注信息
            bytes32 playerOptionKey = keccak256(abi.encodePacked(bettingId, pi.optionId, player));
            MoneyInfo memory money = MoneyInfo({
                token: pi.token,
                sourceAmount: pi.sourceAmount,
                rewardAmount: 0
            });
            playerOptionMoneyInfos[playerOptionKey].push(money);
            // 汇总选项下注信息
            bytes32 optionKey = keccak256(abi.encodePacked(bettingId, pi.optionId));
            bool isExist = false;
            for (uint8 j = 0; j < summaryOptionMoneyInfos[optionKey].length; j++) {
                if (summaryOptionMoneyInfos[optionKey][j].token == pi.token) {
                    isExist = true;
                    summaryOptionMoneyInfos[optionKey][j].sourceAmount += pi.sourceAmount;
                    // summaryOptionMoneyInfos[optionKey][j].value += pi.value;
                    break;
                }
            }
            if (isExist == false) {
                summaryOptionMoneyInfos[optionKey].push(money);
            }
        }
    }

    /**
     * @dev 输入竞猜正确答案
     */
    function submitAnswer(uint256 bettingId, uint8 optionId) external {
        require(bettingInfoMap[bettingId].status == BettingStatus.Answering, "betting not started");
        // require(bettingInfoMap[bettingId].referees.contains(msg.sender), "not referee");
        require(optionId >= 0 && optionId < bettingInfoMap[bettingId].optionNum, "invalid optionId");
        bettingRefereeAnswerMap[bettingId].push(RefereeAnswerInfo({
            referee: msg.sender,
            optionId: optionId
        }));
        bytes32 bettingOptionKey = keccak256(abi.encodePacked(bettingId, optionId));
        // 当前选项投票人数是否超过2/3
        uint8 optionSelectNum = 0;
        for (uint8 i = 0; i < bettingRefereeAnswerMap[bettingId].length; i++) {
            if (bettingRefereeAnswerMap[bettingId][i].optionId == optionId) {
                optionSelectNum += 1;
            }
        }
        if (optionSelectNum >= bettingInfoMap[bettingId].referees.length * 2 / 3) {
            bettingInfoMap[bettingId].answerOptionIndex = optionId;
            bettingInfoMap[bettingId].status = BettingStatus.Settling;
        }
    }

    /**
     * @dev 结算奖励
     */
    function settleReward(uint256 bettingId) external {
        require(bettingInfoMap[bettingId].status == BettingStatus.Settling, "betting not Settling");
        // 算出奖池金额：错误答案的下注金额总和*90%
        uint256 totalRewardAmount = 0;
    }

    /**
     * @dev 领取奖励
     */
    function claimAward(uint256 bettingId) external {
        address sender = msg.sender;
        uint8 answerOptionId = bettingInfoMap[bettingId].answerOptionIndex;
        bytes32 playerOptionKey = keccak256(abi.encodePacked(bettingId, answerOptionId, sender));
        MoneyInfo[] memory moneyInfos = playerOptionMoneyInfos[playerOptionKey];
        for (uint8 i = 0; i < moneyInfos.length; i++) {
            _transferToken(moneyInfos[i].token, moneyInfos[i].rewardAmount, sender);
        }
    }

    /**
     * @dev 提取手续费
     */
    function withdrawFee(uint256 bettingId) external {
        address sender = msg.sender;
        if (bettingInfoMap[bettingId].status != BettingStatus.Ended || sender != bettingInfoMap[bettingId].owner) revert OperationDenied(bettingId);
    }

    /**
     * @dev 获取1个合约的各选项下注信息
     * @param {uint256} bettingId
     * @return MoneyInfo[][]
     */
    function getBettingMoney(uint256 bettingId) external view returns (MoneyInfo[][] memory) {     
        uint8 optionNum = bettingInfoMap[bettingId].optionNum;
        MoneyInfo[][] memory res = new MoneyInfo[][](optionNum);
        for (uint8 i = 0; i < optionNum; i++) {
            bytes32 optionKey = keccak256(abi.encodePacked(bettingId, i));
            MoneyInfo[] memory moneyInfos = summaryOptionMoneyInfos[optionKey];
            res[i] = new MoneyInfo[](moneyInfos.length);
            for (uint8 j = 0; j < moneyInfos.length; j++) {
                res[i][j] = moneyInfos[j];
            }
        }
        return res;
    }

    /**
     * @dev 获取竞猜合约的某玩家的各选项下注信息
     * @param {uint256} bettingId
     * @param {address} player
     * @return MoneyInfo[][]
     */
    function getPlayerPlaceMoney(uint256 bettingId, address player) external view returns (MoneyInfo[][] memory) {
        uint8 optionNum = bettingInfoMap[bettingId].optionNum;
        MoneyInfo[][] memory res = new MoneyInfo[][](optionNum);
        for (uint8 i = 0; i < optionNum; i++) {
            bytes32 playerOptionKey = keccak256(abi.encodePacked(bettingId, i, player));
            MoneyInfo[] memory moneyInfos = playerOptionMoneyInfos[playerOptionKey];
            res[i] = new MoneyInfo[](moneyInfos.length);
            for (uint8 j = 0; j < moneyInfos.length; j++) {
                res[i][j] = moneyInfos[j];
            }
        }
        return res;
    }

    function _transferToken(address _tokenAddress, uint256 amount, address receiver) internal {
        if(_tokenAddress == address(0)) {
            payable(receiver).transfer(amount);
        }else {
            IERC20Metadata(_tokenAddress).transfer(receiver, amount);
        }
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function initialize(
        address _adminContract
    ) external initializer {
        adminContract = _adminContract;
        bettingId = 1;
    }
}
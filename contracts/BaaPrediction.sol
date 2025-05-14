// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaaParam.sol";

contract BaaPrediction is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    struct Prediction {
        uint256 placeStartTime; // 开始下注时间
        uint256 answerTime; // 填写答案时间
        uint256 settleStartTime; // 开始结算时间
        uint256 rewardStartTime; // 开始领奖时间
        uint8[] options; // 竞猜选项
        address[] admins; // 管理员列表
        uint8 correctAnswer; // 正确答案
        bool isSettled; // 是否已结算
        uint256 totalAmount; // 总下注金额
        // mapping(address => uint256) userBets;  // 用户下注金额
        // mapping(string => uint256) optionAmounts;  // 每个选项的下注金额
    }

    struct Wager {
        uint256 sourceAmount; // 本金
        uint256 rewardAmount; // 奖金
    }

    // PerditionId => bytes32: (player_address, optionId) => token => Wager
    mapping(uint256 => mapping(bytes32 => mapping(address => Wager))) predictionBill; // 每个竞猜局的总下注和奖励

    struct PlayerPlaceParam {
        address token;
        uint256 amount;
        uint8 optionId;
    }

    struct ClaimItem {
        uint8 optionId;
        address token;
        uint256 amount;
    }

    struct ClaimParam {
        uint256 predictionId;
        ClaimItem[] items;
    }

    mapping(uint256 => Prediction) public predictions;
    uint256 public predictionCount;
    uint256 public feeRate = 5; // 5% 的手续费
    bool public paused; // 暂停状态
    BaaParam public paramContract;

    event PredictionCreated(
        uint256 indexed predictionId,
        uint256 placeStartTime,
        uint256 answerTime,
        uint256 settleStartTime,
        uint256 rewardStartTime
    );

    event BetPlaced(
        uint256 indexed predictionId,
        address indexed user,
        uint8 option,
        uint256 amount
    );

    event AnswerSubmitted(uint256 indexed predictionId, uint8 answer);

    event RewardClaimed(
        uint256 indexed predictionId,
        address indexed user,
        uint256 amount
    );

    event FeeClaimed(
        uint256 indexed predictionId,
        address indexed admin,
        uint256 amount
    );

    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event AdminAdded(uint256 indexed predictionId, address indexed admin);
    event AdminRemoved(uint256 indexed predictionId, address indexed admin);

    modifier onlyAdmin(uint256 predictionId) {
        bool isAdmin = false;
        for (uint i = 0; i < predictions[predictionId].admins.length; i++) {
            if (predictions[predictionId].admins[i] == msg.sender) {
                isAdmin = true;
                break;
            }
        }
        require(isAdmin, "Not an admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _paramContract) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        paramContract = BaaParam(_paramContract);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function create(
        uint256 _placeStartTime,
        uint256 _answerTime,
        uint256 _settleStartTime,
        uint256 _rewardStartTime,
        uint8[] memory _options,
        address[] memory _admins
    ) external whenNotPaused returns (uint256) {
        require(_placeStartTime < _answerTime, "Invalid time sequence");
        require(_answerTime < _settleStartTime, "Invalid time sequence");
        require(_settleStartTime < _rewardStartTime, "Invalid time sequence");
        require(_options.length > 1, "Need at least 2 options");
        require(_admins.length > 0, "Need at least 1 admin");

        uint256 predictionId = predictionCount++;
        Prediction storage p = predictions[predictionId];
        p.placeStartTime = _placeStartTime;
        p.answerTime = _answerTime;
        p.settleStartTime = _settleStartTime;
        p.rewardStartTime = _rewardStartTime;
        p.options = _options;
        p.admins = _admins;
        p.isSettled = false;

        emit PredictionCreated(
            predictionId,
            _placeStartTime,
            _answerTime,
            _settleStartTime,
            _rewardStartTime
        );
        return predictionId;
    }

    function place(
        uint256 predictionId,
        PlayerPlaceParam[] memory placeParams
    ) external payable whenNotPaused {
        Prediction storage p = predictions[predictionId];
        require(
            block.timestamp >= p.placeStartTime &&
                block.timestamp < p.answerTime,
            "Not in betting period"
        );

        uint256 totalValue = 0;
        for (uint8 i = 0; i < placeParams.length; i++) {
            PlayerPlaceParam memory pp = placeParams[i];
            require(
                pp.optionId >= 0 && pp.optionId < p.options.length,
                "Invalid optionId"
            );

            if (pp.token == address(0)) {
                totalValue += pp.amount;
            } else {
                IERC20(pp.token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    pp.amount
                );
            }

            bytes32 playerId = keccak256(
                abi.encodePacked(msg.sender, pp.optionId)
            );
            predictionBill[predictionId][playerId][pp.token].sourceAmount += pp
                .amount;
            predictionBill[predictionId][playerId][pp.token].rewardAmount += pp
                .amount;
        }

        require(msg.value == totalValue, "Incorrect ETH amount");
        p.totalAmount += totalValue;

        emit BetPlaced(
            predictionId,
            msg.sender,
            p.options[placeParams[0].optionId],
            totalValue
        );
    }

    function submitAnswer(uint256 predictionId, uint8 answerOptionId) external onlyAdmin(predictionId) whenNotPaused {
        Prediction storage p = predictions[predictionId];
        require(
            block.timestamp >= p.answerTime &&
                block.timestamp < p.settleStartTime,
            "Not in answer period"
        );
        require(answerOptionId >= 0 && answerOptionId < p.options.length, "Invalid answer");
        p.correctAnswer = answerOptionId;
        emit AnswerSubmitted(predictionId, answerOptionId);
    }

    // 认领奖金
    function claim(ClaimParam memory claimParam) external whenNotPaused {
        Prediction storage p = predictions[claimParam.predictionId];
        require(block.timestamp >= p.rewardStartTime, "Not in reward period");
        require(p.isSettled, "Prediction not settled");

        for (uint i = 0; i < claimParam.items.length; i++) {
            ClaimItem memory item = claimParam.items[i];
            bytes32 playerId = keccak256(
                abi.encodePacked(msg.sender, item.optionId)
            );
            Wager storage wager = predictionBill[claimParam.predictionId][
                playerId
            ][item.token];

            require(wager.rewardAmount > 0, "No reward to claim");
            uint256 amount = wager.rewardAmount;
            wager.rewardAmount = 0;

            if (item.token == address(0)) {
                (bool success, ) = msg.sender.call{value: amount}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(item.token).safeTransfer(msg.sender, amount);
            }

            emit RewardClaimed(claimParam.predictionId, msg.sender, amount);
        }
    }

    function claimFee(
        uint256 predictionId
    ) external onlyAdmin(predictionId) whenNotPaused {
        Prediction storage p = predictions[predictionId];
        require(block.timestamp >= p.rewardStartTime, "Not in reward period");
        require(p.isSettled, "Prediction not settled");
        require(p.totalAmount > 0, "No bets placed");

        uint256 feeAmount = paramContract.calculateFee(p.totalAmount);
        p.totalAmount -= feeAmount;

        (bool success, ) = msg.sender.call{value: feeAmount}("");
        require(success, "ETH transfer failed");

        emit FeeClaimed(predictionId, msg.sender, feeAmount);
    }

    function addAdmin(
        uint256 predictionId,
        address newAdmin
    ) external onlyAdmin(predictionId) whenNotPaused {
        Prediction storage p = predictions[predictionId];
        p.admins.push(newAdmin);
        emit AdminAdded(predictionId, newAdmin);
    }

    function removeAdmin(
        uint256 predictionId,
        address admin
    ) external onlyAdmin(predictionId) whenNotPaused {
        Prediction storage p = predictions[predictionId];
        require(p.admins.length > 1, "Cannot remove last admin");

        for (uint i = 0; i < p.admins.length; i++) {
            if (p.admins[i] == admin) {
                p.admins[i] = p.admins[p.admins.length - 1];
                p.admins.pop();
                emit AdminRemoved(predictionId, admin);
                break;
            }
        }
    }

    function emergencyWithdraw(uint256 predictionId) external whenPaused {
        Prediction storage p = predictions[predictionId];
        bytes32 playerId = keccak256(abi.encodePacked(msg.sender, 0));
        Wager storage wager = predictionBill[predictionId][playerId][
            address(0)
        ];

        require(wager.sourceAmount > 0, "No funds to withdraw");
        uint256 amount = wager.sourceAmount;
        wager.sourceAmount = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function getPredictionDetails(
        uint256 predictionId
    )
        external
        view
        returns (
            uint256 placeStartTime,
            uint256 answerTime,
            uint256 settleStartTime,
            uint256 rewardStartTime,
            uint8[] memory options,
            address[] memory admins,
            uint8 correctAnswer,
            bool isSettled,
            uint256 totalAmount
        )
    {
        Prediction storage p = predictions[predictionId];
        uint8[] memory tempOptions = p.options;
        address[] memory tempAdmins = p.admins;
        return (
            p.placeStartTime,
            p.answerTime,
            p.settleStartTime,
            p.rewardStartTime,
            tempOptions,
            tempAdmins,
            p.correctAnswer,
            p.isSettled,
            p.totalAmount
        );
    }

    function getUserBet(
        uint256 predictionId,
        address user,
        uint8 optionId,
        address token
    ) external view returns (uint256) {
        bytes32 playerId = keccak256(abi.encodePacked(user, optionId));
        return predictionBill[predictionId][playerId][token].sourceAmount;
    }
}

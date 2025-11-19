// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library LibTermReward {
  struct TickOutput {
    bool crossed;
    uint32 crossedTerm;
    uint96 crossedShare;
    uint160 finishedAreaIfCrossed;
    LibTimeXShareByTerm.Cursor cursor;
  }
}

library LibTimeXShareByTerm {
  struct Cursor {
    uint32 lastTouched;
    uint64 lastIntegratedTimestamp;
    uint96 lastShare;
    uint160 areaInLastTouched;
  }
}

interface IStakingManager {
  type Operation is uint8;
  type Address is address;

  struct Command {
    Operation operation;
    bytes data;
  }

  struct FeeInfo {
    Address recipient;
    uint32 feeBps;
  }

  struct Position {
    uint96 share;
    uint96 credit;
    uint96 claimed;
  }

  error ActiveBuilderLimitExceeded(uint256 maxBuilders);
  error BuilderNotActive(uint32 builderId);
  error BuilderNotEmpty(uint32 builderId);
  error BuilderNotFound(uint32 builderId);
  error DecodeError(Operation operation, bytes data);
  error EmptyBuilderIds();
  error ExceededBps(uint16 bps, uint16 max);
  error FeeTooHigh(uint32 bps);
  error InsufficientAllocation(uint32 builderId, uint96 allocated, int96 delta);
  error InsufficientBalance(address user, uint96 balance, int96 delta);
  error InsufficientFee(uint256 available, uint96 required);
  error NoActiveBuilders();
  error NothingToClaim();
  error SameBuilderId(uint32 builderId);
  error UnsupportedOperation(Operation operation);
  error ZeroBps();
  error ZeroBuilderStake();
  error ZeroClaimFeeAmount();
  error ZeroClaimRewardAmount();
  error ZeroDepositAmount();
  error ZeroMaxActiveBuilders();
  error ZeroMoveAmount();
  error ZeroShareDelta();
  error ZeroStakeAmount();
  error ZeroUnstakeAmount();
  error ZeroWithdrawAmount();

  event Deposited(address indexed user, uint96 amount);
  event FeeClaimed(address indexed by, uint96 amount);
  event FeeInfoUpdated(
    address indexed by, Address previousRecipient, Address newRecipient, uint32 previousFeeBps, uint32 newFeeBps
  );
  event MaxActiveBuildersUpdated(address indexed by, uint16 previousMaxActiveBuilders, uint16 newMaxActiveBuilders);
  event Moved(uint32 indexed fromBuilderId, uint32 indexed toBuilderId, uint96 amount, uint16 bps);
  event PoolTicked(LibTermReward.TickOutput output);
  event PositionCreditUpdated(address indexed user, int256 delta, uint96 newCredit);
  event PositionShareUpdated(address indexed user, int256 delta, uint96 newShare, uint96 totalShare);
  event PrunedEmpty(uint32[] indexed builderIds);
  event PrunedInactive(uint32[] indexed builderIds, uint96 totalRebalanced);
  event RewardCheckpointed(address indexed user, uint256 lastRPS, uint64 lastClaimed, uint96 rewardBank);
  event RewardClaimed(address indexed user, uint96 amount);
  event RewardHarvested(
    uint32 indexed fromBuilderId,
    uint32 indexed toBuilderId,
    uint32 indexed termId,
    uint96 grossReward,
    uint96 netReward,
    uint96 fee,
    uint256 accRewardPerShare
  );
  event UserTicked(address indexed user, LibTermReward.TickOutput output);
  event Withdrawn(address indexed user, uint96 amount);

  function OPERATOR_ROLE() external view returns (bytes32);
  function claimFee(
    uint96 amount
  ) external;
  function claimReward(
    uint96 amount
  ) external;
  function decodeCompoundCommand(
    bytes memory data
  ) external pure returns (uint32 fromBuilderId, uint32 toBuilderId);
  function decodeMoveCommand(
    bytes memory data
  ) external pure returns (uint32 fromBuilderId, uint32 toBuilderId, uint16 bps);
  function decodePruneCommand(
    bytes memory data
  ) external pure returns (uint32[] memory builderIds);
  function deposit() external payable;
  function depositFor(
    address user
  ) external payable;
  function execute(
    Command[] memory commands
  ) external;
  function getAccumulatedRewardPerShare() external view returns (uint256);
  function getAllocated(
    uint32 builderId
  ) external view returns (uint96);
  function getAllocatedBuilders() external view returns (uint32[] memory builderIds);
  function getBuilderAllocation(
    uint32 builderId
  ) external view returns (uint96 allocation);
  function getBuilderRegistry() external view returns (address);
  function getCurrentTerm() external view returns (uint32);
  function getFeeInfo() external view returns (FeeInfo memory);
  function getMaxActiveBuilders() external view returns (uint16);
  function getPendingReward(
    address user
  ) external view returns (uint96);
  function getPoolHistory(
    uint32 term
  ) external view returns (uint96 share, uint160 area, uint256 rps, uint64 startTimestamp, uint64 endTimestamp);
  function getPoolState()
    external
    view
    returns (uint256 accRPS, uint32 currentTerm, uint96 rewardBank, LibTimeXShareByTerm.Cursor memory cursor);
  function getRewardBank() external view returns (uint96);
  function getRpsByTerm(
    uint32 term
  ) external view returns (uint256);
  function getStakingHub() external view returns (address);
  function getTotalAllocation() external view returns (uint96);
  function getTotalShare() external view returns (uint96);
  function getUserHistory(
    address user,
    uint32 term
  ) external view returns (uint160 area);
  function getUserPosition(
    address user
  ) external view returns (Position memory);
  function getUserState(
    address user
  ) external view returns (uint256 lastRPS, uint32 lastClaimed, LibTimeXShareByTerm.Cursor memory cursor);
  function initialize(
    Address admin,
    Address pauser,
    Address operator,
    Address stakingHub,
    Address builderRegistry,
    uint16 maxActiveBuilders,
    FeeInfo memory feeInfo,
    uint32[] memory initBuilderIds
  ) external;
  function pruneEmpty(
    uint32[] memory builderIds
  ) external;
  function pruneInactive() external;
  function withdraw(
    uint96 amount
  ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { RONTransferHelper } from "../extensions/RONTransferHelper.sol";
import "../extensions/collections/HasContracts.sol";
import "../extensions/consumers/PercentageConsumer.sol";
import "../interfaces/IStakingVesting.sol";

import { IRoninValidatorSet } from "../interfaces/validator/IRoninValidatorSet.sol";
import "../utils/CommonErrors.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";
import "@openzeppelin-v4/contracts/proxy/utils/Initializable.sol";

contract StakingVesting is
  IStakingVesting,
  PercentageConsumer,
  HasValidatorDeprecated,
  HasContracts,
  Initializable,
  RONTransferHelper
{
  /// @dev The block bonus for the block producer whenever a new block is mined.
  uint256 internal __deprecatedBlockProducerBonusPerBlock;
  /// @dev The block bonus for the bridge operator whenever a new block is mined.
  uint256 internal __deprecatedBridgeOperatorBonusPerBlock;
  /// @dev The last block number that the staking vesting sent.
  uint256 internal _lastBlockSendingBonus;
  /// @dev The percentage that extracted from reward of block producer for fast finality.
  uint256 internal _fastFinalityRewardPercentage;
  /// @dev The fast finality reward percentage after REP-10 upgrade.
  uint256 internal _fastFinalityRewardPercentageREP10;
  /// @dev The period that REP-10 is activated.
  uint256 internal __deprecatedRep10ActivationPeriod;
  /// @dev The boolean flag to check if REP-10 is activated.
  bool internal __deprecatedIsREP10Activated;
  Reward[] internal _blockRewards;
  uint64 internal _minRewardAmount;
  uint64 internal _maxRewardAmount;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address validatorContract,
    uint256, /* blockProducerBonusPerBlock */ // Deprecated, no longer used
    uint256 /* bridgeOperatorBonusPerBlock */ // Deprecated, no longer used
  ) external payable initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  function initializeV3(
    uint256 fastFinalityRewardPercent
  ) external reinitializer(3) {
    _setFastFinalityRewardPercentage(fastFinalityRewardPercent);
  }

  function initializeV4(
    uint256, /* activatedAtPeriod */
    uint256 /* fastFinalityRewardPercentREP10 */
  ) external reinitializer(4) { }

  function initializeV5(
    uint64 minRewardAmount,
    uint64 maxRewardAmount,
    Reward[] calldata rewards
  ) external reinitializer(5) {
    _setBlockRewardRange(minRewardAmount, maxRewardAmount);
    _updateBlockRewards(rewards);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function updateBlockRewards(
    Reward[] calldata rewards
  ) external onlyAdmin {
    _updateBlockRewards(rewards);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function getBlockRewards() external view returns (Reward[] memory) {
    return _blockRewards;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setBlockRewardRange(uint64 minRewardAmount, uint64 maxRewardAmount) external onlyAdmin {
    _setBlockRewardRange(minRewardAmount, maxRewardAmount);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function getBlockRewardRange() external view returns (uint64 minRewardAmount, uint64 maxRewardAmount) {
    return (_minRewardAmount, _maxRewardAmount);
  }

  /**
   * @dev See {IStakingVesting-setBlockRewardRange}.
   */
  function _setBlockRewardRange(uint64 minRewardAmount, uint64 maxRewardAmount) internal {
    if (minRewardAmount > maxRewardAmount) revert ErrInvalidArguments(msg.sig);
    _minRewardAmount = minRewardAmount;
    _maxRewardAmount = maxRewardAmount;
    emit BlockRewardRangeUpdated(msg.sender, minRewardAmount, maxRewardAmount);
  }

  /**
   * @dev See {IStakingVesting-updateBlockRewards}.
   */
  function _updateBlockRewards(
    Reward[] calldata rewards
  ) internal {
    uint256 length = rewards.length;
    if (length == 0) revert ErrEmptyArray();
    delete _blockRewards;

    uint64 min = _minRewardAmount;
    uint64 max = _maxRewardAmount;

    for (uint256 i; i < length; ++i) {
      if (rewards[i].amount < min || rewards[i].amount > max) revert ErrOutOfBound(rewards[i].amount, min, max);
      // ensure descending order of startBlock
      if (i > 0 && rewards[i].startBlock >= rewards[i - 1].startBlock) {
        revert ErrOutOfOrder(i, rewards[i].startBlock, rewards[i - 1].startBlock);
      }

      _blockRewards.push(rewards[i]);
    }

    emit BlockProducerBonusPerBlockUpdated(msg.sender, rewards);
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function receiveRON() external payable { }

  /**
   * @inheritdoc IStakingVesting
   */
  function blockProducerBlockBonus(
    uint256 blockNumber
  ) public view returns (uint64 bonus) {
    bonus = _minRewardAmount;
    Reward[] memory blockRewards = _blockRewards;
    uint256 length = blockRewards.length;

    for (uint256 i; i < length; ++i) {
      if (blockNumber >= blockRewards[i].startBlock) {
        bonus = blockRewards[i].amount;
        break;
      }
    }
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function lastBlockSendingBonus() external view returns (uint256) {
    return _lastBlockSendingBonus;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function fastFinalityRewardPercentage() external view returns (uint256) {
    return _fastFinalityRewardPercentage;
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function requestBonus(
    bool forBlockProducer,
    bool /* forBridgeOperator */ // Deprecated, no longer used
  )
    external
    onlyContract(ContractType.VALIDATOR)
    returns (bool success, uint256 blockProducerBonus, uint256 bridgeOperatorBonus, uint256 fastFinalityRewardPercent)
  {
    if (block.number <= _lastBlockSendingBonus) revert ErrBonusAlreadySent();

    _lastBlockSendingBonus = block.number;

    blockProducerBonus = forBlockProducer ? blockProducerBlockBonus(block.number) : 0;
    fastFinalityRewardPercent = _fastFinalityRewardPercentage;

    uint256 totalAmount = blockProducerBonus;

    if (totalAmount > 0) {
      address payable validatorContractAddr = payable(msg.sender);

      success = _unsafeSendRON(validatorContractAddr, totalAmount);

      if (!success) {
        emit BonusTransferFailed(
          block.number, validatorContractAddr, blockProducerBonus, bridgeOperatorBonus, address(this).balance
        );
        return (success, 0, 0, 0);
      }

      emit BonusTransferred(block.number, validatorContractAddr, blockProducerBonus, bridgeOperatorBonus);
    }
  }

  /**
   * @inheritdoc IStakingVesting
   */
  function setFastFinalityRewardPercentage(
    uint256 percent
  ) external onlyAdmin {
    if (percent > _MAX_PERCENTAGE) revert ErrInvalidArguments(msg.sig);
    _setFastFinalityRewardPercentage(percent);
  }

  /**
   * @dev Sets the percent of fast finality reward.
   *
   * Emits the event `FastFinalityRewardPercentageUpdated`.
   *
   */
  function _setFastFinalityRewardPercentage(
    uint256 percent
  ) internal {
    _fastFinalityRewardPercentage = percent;
    emit FastFinalityRewardPercentageUpdated(percent);
  }
}

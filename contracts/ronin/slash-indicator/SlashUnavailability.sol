// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./CreditScore.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/slash-indicator/ISlashUnavailability.sol";
import "../../extensions/collections/HasContracts.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import { ErrInvalidThreshold } from "../../utils/CommonErrors.sol";

abstract contract SlashUnavailability is ISlashUnavailability, HasContracts, HasValidatorDeprecated {
  /// @dev The last block that a validator is slashed for unavailability.
  uint256 internal _lastUnavailabilitySlashedBlock;
  /// @dev Mapping from validator address => period index => unavailability indicator.
  mapping(address => mapping(uint256 => uint256)) internal _unavailabilityIndicator;

  /**
   * @dev The mining reward will be deprecated, if (s)he missed more than this threshold.
   * This threshold is applied for tier-1 and tier-3 of unavailability slash.
   */
  uint256 internal _unavailabilityTier1Threshold;
  /**
   * @dev The mining reward will be deprecated, (s)he will be put in jailed, and will be deducted
   * self-staking if (s)he misses more than this threshold. This threshold is applied for tier-2 slash.
   */
  uint256 internal _unavailabilityTier2Threshold;
  /**
   * @dev The amount of RON to deduct from self-staking of a block producer when (s)he is slashed with
   * tier-2 or tier-3.
   *
   */
  uint256 internal _slashAmountForUnavailabilityTier2Threshold;
  /// @dev The number of blocks to jail a block producer when (s)he is slashed with tier-2 or tier-3.
  uint256 internal _jailDurationForUnavailabilityTier2Threshold;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  modifier oncePerBlock() {
    if (block.number <= _lastUnavailabilitySlashedBlock) {
      revert ErrCannotSlashAValidatorTwiceOrSlashMoreThanOneValidatorInOneBlock();
    }

    _lastUnavailabilitySlashedBlock = block.number;
    _;
  }

  function lastUnavailabilitySlashedBlock() external view returns (uint256) {
    return _lastUnavailabilitySlashedBlock;
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function slashUnavailability(TConsensus consensusAddr) external override oncePerBlock {
    if (msg.sender != block.coinbase) revert ErrUnauthorized(msg.sig, RoleAccess.COINBASE);

    address validatorId = __css2cid(consensusAddr);
    if (!_shouldSlash(consensusAddr, validatorId)) {
      // Should return instead of throwing error since this is a part of system transaction.
      return;
    }

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    uint256 period = validatorContract.currentPeriod();
    uint256 count;
    unchecked {
      count = ++_unavailabilityIndicator[validatorId][period];
    }
    uint256 newJailedUntilBlock = Math.addIfNonZero(block.number, _jailDurationForUnavailabilityTier2Threshold);

    if (count == _unavailabilityTier2Threshold) {
      emit Slashed(validatorId, SlashType.UNAVAILABILITY_TIER_2, period);
      validatorContract.execSlash(validatorId, newJailedUntilBlock, _slashAmountForUnavailabilityTier2Threshold, false);
    } else if (count == _unavailabilityTier1Threshold) {
      bool tier1SecondTime = _checkBailedOutAtPeriodById(validatorId, period);
      if (!tier1SecondTime) {
        emit Slashed(validatorId, SlashType.UNAVAILABILITY_TIER_1, period);
        validatorContract.execSlash(validatorId, 0, 0, false);
      } else {
        /// Handles tier-3
        emit Slashed(validatorId, SlashType.UNAVAILABILITY_TIER_3, period);
        validatorContract.execSlash(validatorId, newJailedUntilBlock, _slashAmountForUnavailabilityTier2Threshold, true);
      }
    }
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function setUnavailabilitySlashingConfigs(
    uint256 tier1Threshold,
    uint256 tier2Threshold,
    uint256 slashAmountForTier2,
    uint256 jailDurationForTier2
  ) external override onlyAdmin {
    _setUnavailabilitySlashingConfigs({
      tier1Threshold: tier1Threshold,
      tier2Threshold: tier2Threshold,
      slashAmountForTier2: slashAmountForTier2,
      jailDurationForTier2: jailDurationForTier2
    });
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function getUnavailabilitySlashingConfigs()
    external
    view
    override
    returns (
      uint256 unavailabilityTier1Threshold_,
      uint256 unavailabilityTier2Threshold_,
      uint256 slashAmountForUnavailabilityTier2Threshold_,
      uint256 jailDurationForUnavailabilityTier2Threshold_
    )
  {
    return (
      _unavailabilityTier1Threshold,
      _unavailabilityTier2Threshold,
      _slashAmountForUnavailabilityTier2Threshold,
      _jailDurationForUnavailabilityTier2Threshold
    );
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function currentUnavailabilityIndicator(TConsensus consensus) external view override returns (uint256) {
    return _getUnavailabilityIndicatorById(
      __css2cid(consensus), IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod()
    );
  }

  /**
   * @inheritdoc ISlashUnavailability
   */
  function getUnavailabilityIndicator(
    TConsensus consensus,
    uint256 period
  ) external view virtual override returns (uint256) {
    return _getUnavailabilityIndicatorById(__css2cid(consensus), period);
  }

  function _getUnavailabilityIndicatorById(address validatorId, uint256 period) internal view virtual returns (uint256) {
    return _unavailabilityIndicator[validatorId][period];
  }

  /**
   * @dev Sets the unavailability indicator of the `_validator` at `_period`.
   */
  function _setUnavailabilityIndicator(address _validator, uint256 _period, uint256 _indicator) internal virtual {
    _unavailabilityIndicator[_validator][_period] = _indicator;
  }

  /**
   * @dev See `ISlashUnavailability-setUnavailabilitySlashingConfigs`.
   */
  function _setUnavailabilitySlashingConfigs(
    uint256 tier1Threshold,
    uint256 tier2Threshold,
    uint256 slashAmountForTier2,
    uint256 jailDurationForTier2
  ) internal {
    if (tier1Threshold > tier2Threshold) revert ErrInvalidThreshold(msg.sig);

    _unavailabilityTier1Threshold = tier1Threshold;
    _unavailabilityTier2Threshold = tier2Threshold;
    _slashAmountForUnavailabilityTier2Threshold = slashAmountForTier2;
    _jailDurationForUnavailabilityTier2Threshold = jailDurationForTier2;
    emit UnavailabilitySlashingConfigsUpdated(tier1Threshold, tier2Threshold, slashAmountForTier2, jailDurationForTier2);
  }

  /**
   * @dev Returns whether the account `_addr` should be slashed or not.
   */
  function _shouldSlash(TConsensus consensus, address validatorId) internal view virtual returns (bool);

  /**
   * @dev See `ICreditScore-checkBailedOutAtPeriodById`
   */
  function _checkBailedOutAtPeriodById(address validatorId, uint256 period) internal view virtual returns (bool);

  function __css2cid(TConsensus consensusAddr) internal view virtual returns (address);
}

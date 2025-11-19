// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Math as OpenZeppelinMath } from "@openzeppelin-v4/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin-v4/contracts/utils/math/SafeCast.sol";

import { IStakingManager } from "../../interfaces/external/IStakingManager.sol";
import { IDPoSStakingMigration } from "../../interfaces/staking/IDPoSStakingMigration.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../libraries/Math.sol";
import "../../utils/CommonErrors.sol";
import "./StakingCallback.sol";
import "@openzeppelin-v4/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin-v4/contracts/proxy/utils/Initializable.sol";

contract Staking is IStaking, IDPoSStakingMigration, StakingCallback, Initializable, AccessControlEnumerable {
  using SafeCast for uint256;

  bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.StakingRep4MigratedStorageLocation")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $_StakingRep4MigratedStorageLocation =
    0x02b7258856b9f6bdff23dae2002215e15e9b3a0101a83005baf0725f1e37df00;

  /// @notice Precision factor for accumulated rewards per share calculations (1e18).
  uint256 private constant ACC_PRECISION = 1e18;

  /// @notice Flag indicating whether migration has been triggered (prevents new stakes/delegations).
  bool internal s_migrationTriggered;
  /// @notice Flag indicating whether the contract has been migrated to L2.
  bool internal s_l2Migrated;

  modifier onRep4Migration() {
    uint256 val;
    assembly ("memory-safe") {
      val := sload($_StakingRep4MigratedStorageLocation)
    }

    if (val > 0) revert ErrMigrateWasAdminAlreadyDone();
    _;
  }

  constructor() {
    _disableInitializers();
  }

  receive() external payable {
    if (msg.sender != getContract(ContractType.VALIDATOR)) {
      _requireContract(ContractType.STAKING_MANAGER);
    }
    if (msg.sender != getContract(ContractType.STAKING_MANAGER)) {
      _requireContract(ContractType.VALIDATOR);
    }
  }

  fallback() external payable onlyContract(ContractType.VALIDATOR) { }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    uint256 __minValidatorStakingAmount,
    uint256 __maxCommissionRate,
    uint256 __cooldownSecsToUndelegate,
    uint256 __waitingSecsToRevoke
  ) external initializer {
    _setContract(ContractType.VALIDATOR, __validatorContract);
    _setMinValidatorStakingAmount(__minValidatorStakingAmount);
    _setCommissionRateRange(0, __maxCommissionRate);
    _setCooldownSecsToUndelegate(__cooldownSecsToUndelegate);
    _setWaitingSecsToRevoke(__waitingSecsToRevoke);
  }

  /**
   * @dev Initializes the contract storage V2.
   */
  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  /**
   * @dev Initializes the contract storage V3.
   */
  function initializeV3(
    address __profileContract
  ) external reinitializer(3) {
    _setContract(ContractType.PROFILE, __profileContract);
  }

  function initializeV4(
    address admin,
    address migrator
  ) external reinitializer(4) {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(MIGRATOR_ROLE, migrator);
  }

  function initializeV5(
    address stakingManager,
    address migrator
  ) external reinitializer(5) {
    _setContract(ContractType.STAKING_MANAGER, stakingManager);
    _grantRole(MIGRATOR_ROLE, migrator);
  }

  /// @inheritdoc IDPoSStakingMigration
  function triggerMigration() external onlyRole(MIGRATOR_ROLE) {
    require(!s_migrationTriggered, "Migration already triggered");
    s_migrationTriggered = true;
    IStakingManager(getContract(ContractType.STAKING_MANAGER)).deposit{ value: address(this).balance }();
    emit MigrationTriggered(msg.sender);
  }

  /// @inheritdoc IDPoSStakingMigration
  function setL2Migrated(
    bool status
  ) external onlyRole(MIGRATOR_ROLE) {
    s_l2Migrated = status;
    emit L2MigrationStatusUpdated(msg.sender, status);
  }

  /// @inheritdoc IDPoSStakingMigration
  function isL2Migrated() external view returns (bool) {
    return s_l2Migrated;
  }

  /// @inheritdoc IDPoSStakingMigration
  function execRenounceAndDeprecatePool(
    address poolId
  ) external onlyPoolAdmin(_poolDetail[poolId], msg.sender) {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    uint256 revokingTimestamp = validatorContract.getCandidateInfoById(poolId).revokingTimestamp;
    uint256 currentPeriod = validatorContract.currentPeriod();

    require(s_l2Migrated, ErrL2MigrationNotCompleted());
    require(
      revokingTimestamp != 0 && revokingTimestamp < block.timestamp,
      ErrPoolRevokingTimestampNotReach(poolId, revokingTimestamp, block.timestamp)
    );

    _deprecatePool(poolId, currentPeriod);

    emit PoolDeprecated(poolId);
  }

  /// @notice Delegates tokens to a validator pool.
  /// @dev Overrides parent to block delegation after migration is triggered.
  ///      Reverts if migration is active.
  /// @param _pool Storage reference to the pool detail.
  /// @param delegator Address of the delegator.
  /// @param amount Amount to delegate.
  function _delegate(
    PoolDetail storage _pool,
    address delegator,
    uint256 amount
  ) internal virtual override {
    require(!s_migrationTriggered, "Staking is deprecated, please migrate to the new staking contract");
    super._delegate(_pool, delegator, amount);
  }

  /// @notice Stakes tokens into a validator pool.
  /// @dev Overrides parent to block staking after migration is triggered.
  ///      Reverts if migration is active.
  /// @param _pool Storage reference to the pool detail.
  /// @param requester Address of the staker.
  /// @param amount Amount to stake.
  function _stake(
    PoolDetail storage _pool,
    address requester,
    uint256 amount
  ) internal virtual override {
    require(!s_migrationTriggered, "Staking is deprecated, please migrate to the new staking contract");
    super._stake(_pool, requester, amount);
  }

  /// @notice Undelegates tokens from a validator pool.
  /// @dev Overrides parent to withdraw from StakingManager and restake farmed rewards.
  ///      After undelegation, the delegator's proportional share of farmed rewards is claimed
  ///      and restaked into StakingManager on their behalf.
  /// @param consensusAddr The consensus address of the validator.
  /// @param _pool Storage reference to the pool detail.
  /// @param delegator Address of the delegator.
  /// @param amount Amount to undelegate.
  function _undelegate(
    TConsensus consensusAddr,
    PoolDetail storage _pool,
    address delegator,
    uint256 amount
  ) internal virtual override {
    super._undelegate(consensusAddr, _pool, delegator, amount);
    _withdrawAndClaimFarmedReward(delegator, amount);
  }

  /// @notice Unstakes tokens from a validator pool.
  /// @dev Overrides parent to withdraw from StakingManager and restake farmed rewards.
  ///      After unstaking, the requester's proportional share of farmed rewards is claimed
  ///      and restaked into StakingManager on their behalf.
  /// @param _pool Storage reference to the pool detail.
  /// @param requester Address of the staker.
  /// @param amount Amount to unstake.
  function _unstake(
    PoolDetail storage _pool,
    address requester,
    uint256 amount
  ) internal virtual override {
    super._unstake(_pool, requester, amount);
    _withdrawAndClaimFarmedReward(requester, amount);
  }

  /// @notice Claims pending rewards for a user from a pool.
  /// @dev Overrides parent to withdraw from StakingManager and restake farmed rewards.
  ///      After claiming, the user's proportional share of farmed rewards is claimed
  ///      and restaked into StakingManager on their behalf.
  /// @param poolId Address of the pool.
  /// @param user Address of the user claiming rewards.
  /// @param lastPeriod The last period up to which rewards are claimed.
  /// @return amount The amount of rewards claimed.
  function _claimReward(
    address poolId,
    address user,
    uint256 lastPeriod
  ) internal override returns (uint256 amount) {
    amount = super._claimReward(poolId, user, lastPeriod);
    _withdrawAndClaimFarmedReward(user, amount);
  }

  /// @notice Internal function to withdraw from StakingManager and claim farmed rewards from new StakingManager.
  /// @dev Core migration logic that handles proportional reward distribution:
  ///      1. Withdraws the specified amount from StakingManager
  ///      2. Calculates the user's proportional share of farmed rewards
  ///      3. Claims that reward share
  ///      4. Transfers RON to the user
  ///
  ///      The reward calculation uses: reward = (poolReward / poolShare) * amount
  ///      This ensures users get their fair share of rewards accumulated in StakingManager.
  ///
  /// @param account Address of the user to process rewards for.
  /// @param amount Amount being withdrawn (used to calculate proportional rewards).
  function _withdrawAndClaimFarmedReward(
    address account,
    uint256 amount
  ) internal {
    if (!(s_migrationTriggered && amount != 0)) return;

    IStakingManager stakingManager = IStakingManager(getContract(ContractType.STAKING_MANAGER));
    uint96 poolShare = stakingManager.getUserPosition(address(this)).share;
    uint96 poolReward = stakingManager.getPendingReward(address(this));

    stakingManager.withdraw(amount.toUint96());

    uint96 rps = OpenZeppelinMath.mulDiv(poolReward, ACC_PRECISION, poolShare).toUint96();
    uint96 reward = OpenZeppelinMath.mulDiv(rps, amount, ACC_PRECISION).toUint96();
    if (reward == 0) return;

    stakingManager.claimReward(reward);
    _transferRON(payable(account), reward);
  }

  /**
   * @dev Migrate REP-4
   */
  function migrateWasAdmin(
    address[] calldata poolIds,
    address[] calldata admins,
    bool[] calldata flags
  ) external onRep4Migration onlyRole(MIGRATOR_ROLE) {
    if (poolIds.length != admins.length || poolIds.length != flags.length) {
      revert ErrInvalidArguments(msg.sig);
    }

    for (uint256 i; i < poolIds.length; ++i) {
      _poolDetail[poolIds[i]].wasAdmin[admins[i]] = flags[i];
    }

    emit MigrateWasAdminFinished();
  }

  /**
   * @dev Mark the REP-4 migration is finished. Disable the `migrateWasAdmin` method.
   */
  function disableMigrateWasAdmin() external onRep4Migration onlyRole(MIGRATOR_ROLE) {
    assembly {
      sstore($_StakingRep4MigratedStorageLocation, 0x01)
    }

    emit MigrateWasAdminDisabled();
  }

  /**
   * @inheritdoc IStaking
   */
  function execRecordRewards(
    address[] calldata poolIds,
    uint256[] calldata rewards,
    uint256 period
  ) external payable override onlyContract(ContractType.VALIDATOR) {
    _recordRewards(poolIds, rewards, period);
    if (!(s_migrationTriggered && msg.value != 0)) return;
    IStakingManager(getContract(ContractType.STAKING_MANAGER)).deposit{ value: msg.value }();
  }

  /**
   * @inheritdoc IStaking
   */
  function execDeductStakingAmount(
    address poolId,
    uint256 amount
  ) external override onlyContract(ContractType.VALIDATOR) returns (uint256 actualDeductingAmount_) {
    actualDeductingAmount_ = _deductStakingAmount(_poolDetail[poolId], amount);
    address payable validatorContractAddr = payable(msg.sender);
    if (!_unsafeSendRON(validatorContractAddr, actualDeductingAmount_)) {
      emit StakingAmountDeductFailed(poolId, validatorContractAddr, actualDeductingAmount_, address(this).balance);
    }
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _currentPeriod() internal view virtual override returns (uint256) {
    return IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
  }

  /**
   * @inheritdoc CandidateStaking
   */
  function _deductStakingAmount(
    PoolDetail storage _pool,
    uint256 amount
  ) internal override returns (uint256 actualDeductingAmount_) {
    actualDeductingAmount_ = Math.min(_pool.stakingAmount, amount);

    _pool.stakingAmount -= actualDeductingAmount_;
    _changeDelegatingAmount(
      _pool,
      _pool.__shadowedPoolAdmin,
      _pool.stakingAmount,
      Math.subNonNegative(_pool.stakingTotal, actualDeductingAmount_)
    );
    emit Unstaked(_pool.pid, actualDeductingAmount_);

    // pool admin will receive the farmed rewards if they:
    // 1. are slashed by the validator set
    // 2. renounce validator
    _withdrawAndClaimFarmedReward(_pool.__shadowedPoolAdmin, actualDeductingAmount_);
  }
}

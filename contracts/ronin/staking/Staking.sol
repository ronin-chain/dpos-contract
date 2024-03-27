// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../libraries/Math.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../utils/CommonErrors.sol";
import "./StakingCallback.sol";

contract Staking is IStaking, StakingCallback, Initializable, AccessControlEnumerable {
  bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.StakingRep4MigratedStorageLocation")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $_StakingRep4MigratedStorageLocation =
    0x02b7258856b9f6bdff23dae2002215e15e9b3a0101a83005baf0725f1e37df00;

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

  receive() external payable onlyContract(ContractType.VALIDATOR) { }

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
  function initializeV3(address __profileContract) external reinitializer(3) {
    _setContract(ContractType.PROFILE, __profileContract);
  }

  function initializeV4(address admin, address migrator) external reinitializer(4) {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(MIGRATOR_ROLE, migrator);
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

    for (uint i; i < poolIds.length; ++i) {
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
  }

  /**
   * @inheritdoc IStaking
   */
  function execDeductStakingAmount(
    address poolId,
    uint256 amount
  ) external override onlyContract(ContractType.VALIDATOR) returns (uint256 actualDeductingAmount_, bool success) {
    actualDeductingAmount_ = _deductStakingAmount(_poolDetail[poolId], amount);
    address payable validatorContractAddr = payable(msg.sender);
    success = true;
    if (!_unsafeSendRON(validatorContractAddr, actualDeductingAmount_)) {
      success = false;
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
  }
}

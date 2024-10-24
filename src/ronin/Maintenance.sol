// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../extensions/collections/HasContracts.sol";
import "../interfaces/IMaintenance.sol";
import "../interfaces/IProfile.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";
import "../libraries/Math.sol";

import { ErrUnauthorized, RoleAccess } from "../utils/CommonErrors.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";
import "@openzeppelin-v4/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-v4/contracts/utils/structs/EnumerableSet.sol";

contract Maintenance is IMaintenance, HasContracts, HasValidatorDeprecated, Initializable {
  using Math for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev Mapping from candidate id => maintenance schedule.
  mapping(address => Schedule) internal _schedule;

  /// @dev The min duration to maintenance in blocks.
  uint256 internal _minMaintenanceDurationInBlock;
  /// @dev The max duration to maintenance in blocks.
  uint256 internal _maxMaintenanceDurationInBlock;
  /// @dev The offset to the min block number that the schedule can start.
  uint256 internal _minOffsetToStartSchedule;
  /// @dev The offset to the max block number that the schedule can start.
  uint256 internal _maxOffsetToStartSchedule;
  /// @dev The max number of scheduled maintenances.
  uint256 internal _maxSchedule;
  /// @dev The cooldown time to request new schedule.
  uint256 internal _cooldownSecsToMaintain;
  /// @dev The set of scheduled candidates.
  EnumerableSet.AddressSet internal _scheduledCandidates;

  constructor() {
    _disableInitializers();
  }

  modifier syncSchedule() {
    _syncSchedule();
    _;
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address validatorContract,
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedule_,
    uint256 cooldownSecsToMaintain_
  ) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
    _setMaintenanceConfig(
      minMaintenanceDurationInBlock_,
      maxMaintenanceDurationInBlock_,
      minOffsetToStartSchedule_,
      maxOffsetToStartSchedule_,
      maxSchedule_,
      cooldownSecsToMaintain_
    );
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  function initializeV3(
    address profileContract_
  ) external reinitializer(3) {
    _setContract(ContractType.PROFILE, profileContract_);
  }

  function initializeV4() external reinitializer(4) {
    unchecked {
      address[] memory validatorIds = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).getValidatorIds();
      uint256 length = validatorIds.length;

      for (uint256 i; i < length; ++i) {
        if (_checkScheduledById(validatorIds[i])) {
          _scheduledCandidates.add(validatorIds[i]);
        }
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function minMaintenanceDurationInBlock() external view returns (uint256) {
    return _minMaintenanceDurationInBlock;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maxMaintenanceDurationInBlock() external view returns (uint256) {
    return _maxMaintenanceDurationInBlock;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function minOffsetToStartSchedule() external view returns (uint256) {
    return _minOffsetToStartSchedule;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maxOffsetToStartSchedule() external view returns (uint256) {
    return _maxOffsetToStartSchedule;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maxSchedule() external view returns (uint256) {
    return _maxSchedule;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function cooldownSecsToMaintain() external view returns (uint256) {
    return _cooldownSecsToMaintain;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function setMaintenanceConfig(
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedule_,
    uint256 cooldownSecsToMaintain_
  ) external onlyAdmin {
    _setMaintenanceConfig(
      minMaintenanceDurationInBlock_,
      maxMaintenanceDurationInBlock_,
      minOffsetToStartSchedule_,
      maxOffsetToStartSchedule_,
      maxSchedule_,
      cooldownSecsToMaintain_
    );
  }

  /**
   * @inheritdoc IMaintenance
   */
  function schedule(TConsensus consensusAddr, uint256 startedAtBlock, uint256 endedAtBlock) external override {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    address candidateId = __css2cid(consensusAddr);

    if (!validatorContract.isBlockProducerById(candidateId)) revert ErrUnauthorized(msg.sig, RoleAccess.BLOCK_PRODUCER);
    _requireCandidateAdmin(candidateId);
    if (_checkScheduledById(candidateId)) revert ErrAlreadyScheduled();
    if (!_checkCooldownEndedById(candidateId)) revert ErrCooldownTimeNotYetEnded();
    if (_syncSchedule() >= _maxSchedule) revert ErrTotalOfSchedulesExceeded();
    if (!startedAtBlock.inRange(block.number + _minOffsetToStartSchedule, block.number + _maxOffsetToStartSchedule)) {
      revert ErrStartBlockOutOfRange();
    }
    if (startedAtBlock >= endedAtBlock) revert ErrStartBlockOutOfRange();

    uint256 maintenanceElapsed = endedAtBlock - startedAtBlock + 1;

    if (!maintenanceElapsed.inRange(_minMaintenanceDurationInBlock, _maxMaintenanceDurationInBlock)) {
      revert ErrInvalidMaintenanceDuration();
    }
    if (!validatorContract.epochEndingAt(startedAtBlock - 1)) revert ErrStartBlockOutOfRange();
    if (!validatorContract.epochEndingAt(endedAtBlock)) revert ErrEndBlockOutOfRange();

    Schedule storage _sSchedule = _schedule[candidateId];
    _sSchedule.from = startedAtBlock;
    _sSchedule.to = endedAtBlock;
    _sSchedule.lastUpdatedBlock = block.number;
    _sSchedule.requestTimestamp = block.timestamp;
    _scheduledCandidates.add(candidateId);

    emit MaintenanceScheduled(candidateId, _sSchedule);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function cancelSchedule(
    TConsensus consensusAddr
  ) external override syncSchedule {
    address candidateId = __css2cid(consensusAddr);

    _requireCandidateAdmin(candidateId);

    if (!_checkScheduledById(candidateId)) revert ErrUnexistedSchedule();
    if (_checkMaintainedById(candidateId, block.number)) revert ErrAlreadyOnMaintenance();

    Schedule storage _sSchedule = _schedule[candidateId];
    delete _sSchedule.from;
    delete _sSchedule.to;
    _sSchedule.lastUpdatedBlock = block.number;
    _scheduledCandidates.remove(candidateId);

    emit MaintenanceScheduleCancelled(candidateId);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function exitMaintenance(
    TConsensus consensusAddr
  ) external syncSchedule {
    address candidateId = __css2cid(consensusAddr);
    uint256 currentBlock = block.number;

    _requireCandidateAdmin(candidateId);

    if (!_checkMaintainedById(candidateId, currentBlock)) revert ErrNotOnMaintenance();

    Schedule storage _sSchedule = _schedule[candidateId];
    _sSchedule.to = currentBlock;
    _sSchedule.lastUpdatedBlock = currentBlock;
    _scheduledCandidates.remove(candidateId);

    emit MaintenanceExited(candidateId);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function getSchedule(
    TConsensus consensusAddr
  ) external view override returns (Schedule memory) {
    return _schedule[__css2cid(consensusAddr)];
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintained(
    TConsensus[] calldata addrList,
    uint256 atBlock
  ) external view override returns (bool[] memory) {
    address[] memory idList = __css2cidBatch(addrList);
    return _checkManyMaintainedById(idList, atBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintainedById(
    address[] calldata idList,
    uint256 atBlock
  ) external view override returns (bool[] memory) {
    return _checkManyMaintainedById(idList, atBlock);
  }

  function _checkManyMaintainedById(
    address[] memory idList,
    uint256 atBlock
  ) internal view returns (bool[] memory resList) {
    uint256 length = idList.length;
    resList = new bool[](length);

    for (uint256 i; i < length; ++i) {
      resList[i] = _checkMaintainedById(idList[i], atBlock);
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintainedInBlockRange(
    TConsensus[] calldata addrList,
    uint256 fromBlock,
    uint256 toBlock
  ) external view override returns (bool[] memory) {
    address[] memory idList = __css2cidBatch(addrList);
    return _checkManyMaintainedInBlockRangeById(idList, fromBlock, toBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintainedInBlockRangeById(
    address[] calldata idList,
    uint256 fromBlock,
    uint256 toBlock
  ) external view override returns (bool[] memory) {
    return _checkManyMaintainedInBlockRangeById(idList, fromBlock, toBlock);
  }

  function _checkManyMaintainedInBlockRangeById(
    address[] memory idList,
    uint256 fromBlock,
    uint256 toBlock
  ) internal view returns (bool[] memory resList) {
    uint256 length = idList.length;
    resList = new bool[](length);

    for (uint256 i; i < length; ++i) {
      resList[i] = _maintainingInBlockRange(idList[i], fromBlock, toBlock);
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function totalSchedule() public view returns (uint256 count) {
    unchecked {
      address[] memory mSchedules = _scheduledCandidates.values();
      uint256 length = mSchedules.length;

      for (uint256 i; i < length; ++i) {
        if (_checkScheduledById(mSchedules[i])) ++count;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintained(TConsensus consensusAddr, uint256 atBlock) external view override returns (bool) {
    return _checkMaintainedById(__css2cid(consensusAddr), atBlock);
  }

  /**
   * @dev Synchronizes the schedule by checking if the scheduled candidates are still in maintenance and removes the candidates that are no longer in maintenance.
   * @return count The number of active schedules.
   */
  function _syncSchedule() internal returns (uint256 count) {
    unchecked {
      address[] memory mSchedules = _scheduledCandidates.values();
      uint256 length = mSchedules.length;

      for (uint256 i; i < length; ++i) {
        if (_checkScheduledById(mSchedules[i])) {
          ++count;
        } else {
          _scheduledCandidates.remove(mSchedules[i]);
        }
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintainedById(address candidateId, uint256 atBlock) external view override returns (bool) {
    return _checkMaintainedById(candidateId, atBlock);
  }

  function _checkMaintainedById(address candidateId, uint256 atBlock) internal view returns (bool) {
    Schedule storage _s = _schedule[candidateId];
    return _s.from <= atBlock && atBlock <= _s.to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintainedInBlockRange(
    TConsensus consensusAddr,
    uint256 fromBlock,
    uint256 toBlock
  ) public view override returns (bool) {
    return _maintainingInBlockRange(__css2cid(consensusAddr), fromBlock, toBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkScheduled(
    TConsensus consensusAddr
  ) external view override returns (bool) {
    return _checkScheduledById(__css2cid(consensusAddr));
  }

  function _checkScheduledById(
    address candidateId
  ) internal view returns (bool) {
    return block.number <= _schedule[candidateId].to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkCooldownEnded(
    TConsensus consensusAddr
  ) external view override returns (bool) {
    return _checkCooldownEndedById(__css2cid(consensusAddr));
  }

  function _checkCooldownEndedById(
    address candidateId
  ) internal view returns (bool) {
    unchecked {
      return block.timestamp > _schedule[candidateId].requestTimestamp + _cooldownSecsToMaintain;
    }
  }

  /**
   * @dev Sets the min block period and max block period to maintenance.
   *
   * Requirements:
   * - The max period is larger than the min period.
   *
   * Emits the event `MaintenanceConfigUpdated`.
   *
   */
  function _setMaintenanceConfig(
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedule_,
    uint256 cooldownSecsToMaintain_
  ) internal {
    if (minMaintenanceDurationInBlock_ >= maxMaintenanceDurationInBlock_) revert ErrInvalidMaintenanceDurationConfig();
    if (minOffsetToStartSchedule_ >= maxOffsetToStartSchedule_) revert ErrInvalidOffsetToStartScheduleConfigs();

    _minMaintenanceDurationInBlock = minMaintenanceDurationInBlock_;
    _maxMaintenanceDurationInBlock = maxMaintenanceDurationInBlock_;
    _minOffsetToStartSchedule = minOffsetToStartSchedule_;
    _maxOffsetToStartSchedule = maxOffsetToStartSchedule_;
    _maxSchedule = maxSchedule_;
    _cooldownSecsToMaintain = cooldownSecsToMaintain_;
    emit MaintenanceConfigUpdated(
      minMaintenanceDurationInBlock_,
      maxMaintenanceDurationInBlock_,
      minOffsetToStartSchedule_,
      maxOffsetToStartSchedule_,
      maxSchedule_,
      cooldownSecsToMaintain_
    );
  }

  /**
   * @dev Check if the validator was maintaining in the current period.
   *
   * Note: This method should be called at the end of the period.
   */
  function _maintainingInBlockRange(
    address candidateId,
    uint256 fromBlock,
    uint256 toBlock
  ) private view returns (bool) {
    Schedule storage s = _schedule[candidateId];
    return Math.twoRangeOverlap(fromBlock, toBlock, s.from, s.to);
  }

  /**
   * @dev Checks if the caller is a candidate admin for the given candidate ID.
   */
  function _requireCandidateAdmin(
    address candidateId
  ) internal view {
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdminById(candidateId, msg.sender)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    }
  }

  function __css2cid(
    TConsensus consensusAddr
  ) internal view returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  function __css2cidBatch(
    TConsensus[] memory consensusAddrs
  ) internal view returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }
}

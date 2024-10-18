// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { HasTrustedOrgDeprecated } from "../../../utils/DeprecatedSlots.sol";
import "../../../extensions/collections/HasContracts.sol";
import "../../../interfaces/validator/info-fragments/IValidatorInfoV2.sol";
import { IProfile } from "../../../interfaces/IProfile.sol";
import { IRandomBeacon } from "../../../interfaces/random-beacon/IRandomBeacon.sol";
import { TConsensus } from "../../../udvts/Types.sol";

abstract contract ValidatorInfoStorageV2 is IValidatorInfoV2, HasContracts, HasTrustedOrgDeprecated {
  /// @dev The maximum number of validator.
  uint256 internal __deprecatedMaxValidatorNumber;

  /// @dev The total of validators
  uint256 internal _validatorCount;
  /// @dev Mapping from validator index => validator id address
  mapping(uint256 idx => address cid) internal _validatorIds;
  /// @dev Mapping from validator id => boolean indicating whether the validator is a block producer
  mapping(address cid => bool isBlockProducer) internal _validatorMap;
  /// @dev The number of slot that is reserved for prioritized validators
  uint256 internal __deprecatedMaxPrioritizedValidatorNumber;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  function validatorCount() external view returns (uint256) {
    return _validatorCount;
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getValidators() public view override returns (TConsensus[] memory consensusList) {
    return __cid2cssBatch(getValidatorIds());
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getValidatorIds() public view override returns (address[] memory cids) {
    cids = new address[](_validatorCount);
    address iValidator;
    for (uint i; i < cids.length;) {
      iValidator = _validatorIds[i];
      cids[i] = iValidator;

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getBlockProducers() public view override returns (TConsensus[] memory consensusList) {
    return __cid2cssBatch(getBlockProducerIds());
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getBlockProducerIds() public view override returns (address[] memory cids) {
    cids = new address[](_validatorCount);
    uint256 count = 0;
    for (uint i; i < cids.length;) {
      address validatorId = _validatorIds[i];
      if (_isBlockProducerById(validatorId)) {
        cids[count++] = validatorId;
      }

      unchecked {
        ++i;
      }
    }

    assembly ("memory-safe") {
      mstore(cids, count)
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function isBlockProducer(
    TConsensus consensusAddr
  ) public view override returns (bool) {
    return _isBlockProducerById(__css2cid(consensusAddr));
  }

  function isBlockProducerById(
    address id
  ) external view override returns (bool) {
    return _isBlockProducerById(id);
  }

  function _isBlockProducerById(
    address id
  ) internal view returns (bool yes) {
    yes = _validatorMap[id];
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function totalBlockProducer() external view returns (uint256 total) {
    unchecked {
      for (uint i; i < _validatorCount; i++) {
        if (_isBlockProducerById(_validatorIds[i])) {
          total++;
        }
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return IRandomBeacon(getContract(ContractType.RANDOM_BEACON)).getValidatorThreshold(IRandomBeacon.ValidatorType.All);
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function maxPrioritizedValidatorNumber() external view override returns (uint256 _maximumPrioritizedValidatorNumber) {
    return IRandomBeacon(getContract(ContractType.RANDOM_BEACON)).getValidatorThreshold(
      IRandomBeacon.ValidatorType.Governing
    );
  }

  /// @dev See {RoninValidatorSet-__css2cid}
  function __css2cid(
    TConsensus consensusAddr
  ) internal view virtual returns (address);

  /// @dev See {RoninValidatorSet-__css2cidBatch}
  function __css2cidBatch(
    TConsensus[] memory consensusAddrs
  ) internal view virtual returns (address[] memory);

  /// @dev See {RoninValidatorSet-__cid2cssBatch}
  function __cid2cssBatch(
    address[] memory cids
  ) internal view virtual returns (TConsensus[] memory);
}

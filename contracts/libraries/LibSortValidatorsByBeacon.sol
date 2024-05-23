// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibArray } from "./LibArray.sol";
import { IndexMap, LibIndexMap } from "./LibIndexMap.sol";
import { notInIndexMapFilter, nonZeroTrustedWeightFilter } from "../utils/Filters.sol";

library LibSortValidatorsByBeacon {
  using LibArray for uint256[];
  using LibArray for address[];

  /// @dev value is equal to keccak256(abi.encode(uint256(keccak256("@ronin.RandomBeacon.storage.sortedValidatorsByBeacon")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_SortedValidatorByBeaconStorageLocation =
    0x8593e13447c7ce85611f094407732145bce33e516174eca63d12235f14022600;

  struct SortedValidatorStorage {
    // Number of non-rotating validators to pick.
    uint16 _nRV;
    // Governance Validators + Standard Validators
    address[] _nonRotatingValidators;
    // Packed data of Rotating Validators and their stake amounts
    RotatingValidatorStorage[] _rotatingValidators;
  }

  struct RotatingValidatorStorage {
    address _cid;
    uint96 _staked;
  }

  struct UnsortedValidatorStorage {
    // An array of unsorted validator addresses.
    address[] _cids;
  }

  struct ValidatorStorage {
    // A boolean value indicating whether all the validators are picked.
    bool _pickAll;
    // Use when rotating validators are changed per epoch
    SortedValidatorStorage _sorted;
    // Use when all the validators are saved (when number of validators is less than the sum of nGV, nSV, and nRV)
    UnsortedValidatorStorage _unsorted;
  }

  /// @dev Event emitted when the validator set is saved.
  event ValidatorSetSaved(
    uint256 indexed period,
    bool pickedAll,
    uint256 nRV,
    address[] nonRotatingValidators,
    address[] rotatingValidators,
    uint256[] rotatingStakeAmounts
  );

  /**
   * @dev Sorts and saves the validator set based on the given parameters.
   *
   * - Filters and separates Governance Validators, Standard Validators, and Non-Standard Validators
   * - If the number of validators is less than the sum of `nGV`, `nSV`, and `nRV`, saves all cids as unsorted validators
   * - Otherwise, saves two sets of validators: non-rotating validators and rotating validators
   * - This function should only be called once per period
   *
   * @param period The period value.
   * @param nGV The number of governance validators.
   * @param nSV The number of standard validators.
   * @param nRV The number of non-standard validators.
   * @param cids The array of validator candidate ids.
   * @param trustedWeights The array of trusted weights for validators.
   */
  function filterAndSaveValidators(
    uint256 period,
    uint256 nGV,
    uint256 nSV,
    uint256 nRV,
    address[] memory cids,
    uint256[] memory stakedAmounts,
    uint256[] memory trustedWeights
  ) internal {
    unchecked {
      uint256 length = cids.length;
      if (!(length == stakedAmounts.length && length == trustedWeights.length)) revert LibArray.ErrLengthMismatch();
      // save all cids if the number of cids is less than the max pick config
      if (nGV + nSV + nRV >= length) {
        _cleanAndUseAllCids(period, cids);
        return;
      }

      // create indices for validators
      uint256[] memory indices = LibArray.arange(length);
      // create bitmap for indices of validators
      IndexMap memory picked = LibIndexMap.create(uint16(length));
      // filter and pick governance validators
      uint256[] memory gvIndices = indices.filterBy(trustedWeights, nonZeroTrustedWeightFilter);
      // pick top `nGV` governance validators
      gvIndices = gvIndices.pickTopKByValues(stakedAmounts.take(gvIndices), nGV);
      // mark the existence of governance validators
      picked.setBatch(gvIndices);

      // filter and pick standard validators
      // If the number of governance validators is fewer than the maximum governance validator,
      // Then the remaining number is transferred to standard validator case
      nSV += nGV - gvIndices.length;
      uint256[] memory svIndices = indices.filterByIndexMap(picked, notInIndexMapFilter);
      // pick top `nSV` standard validators
      svIndices = svIndices.pickTopKByValues(stakedAmounts.take(svIndices), nSV);
      // mark the existence of standard validators
      picked.setBatch(svIndices);

      // filter and pick non-standard validators
      uint256[] memory rvIndices = indices.filterByIndexMap(picked, notInIndexMapFilter);

      _cleanAndUpdateNewCids({
        nRV: nRV,
        period: period,
        nonRotatingValidators: cids.take(gvIndices.concat(svIndices)),
        rotatingStakeAmounts: stakedAmounts.take(rvIndices),
        rotatingValidators: cids.take(rvIndices)
      });
    }
  }

  /**
   * @dev Saves the all cids for a given period.
   *
   * - Clean up the previous sorted data
   * - Save all cids as unsorted validators.
   */
  function _cleanAndUseAllCids(uint256 period, address[] memory cids) private {
    ValidatorStorage storage $ = _getValidatorPerPeriodLocation();
    SortedValidatorStorage storage $sortedValidatorStorage = $._sorted;

    $._pickAll = true;
    $._unsorted._cids = cids;

    // delete the previous sorted data
    delete $sortedValidatorStorage._nRV;
    delete $sortedValidatorStorage._rotatingValidators;
    delete $sortedValidatorStorage._nonRotatingValidators;

    emit ValidatorSetSaved({
      period: period,
      pickedAll: true,
      nRV: 0,
      nonRotatingValidators: cids,
      rotatingValidators: new address[](0),
      rotatingStakeAmounts: new uint256[](0)
    });
  }

  /**
   * @dev Saves the sorted validators for a given period, beacon, and number of non-rotating validators.
   *
   * - Clean up the previous unsorted data
   * - Replace the non-rotating validators set with the new one
   * - Delete the previous packed rotating validators set
   * - Save the new packed rotating validators set
   *
   * @param period The period for which the validators are being saved.
   * @param nRV The number of non-standard validators.
   * @param nonRotatingValidators An array of addresses representing the non-rotating validators.
   * @param rotatingValidators An array of addresses representing the rotating validators.
   * @param rotatingStakeAmounts An array of stake values corresponding to the rotating validators.
   */
  function _cleanAndUpdateNewCids(
    uint256 period,
    uint256 nRV,
    address[] memory nonRotatingValidators,
    address[] memory rotatingValidators,
    uint256[] memory rotatingStakeAmounts
  ) private {
    ValidatorStorage storage $validatorStorage = _getValidatorPerPeriodLocation();
    SortedValidatorStorage storage $sortedValidatorStorage = $validatorStorage._sorted;

    // delete previous unsorted data
    delete $validatorStorage._pickAll;
    delete $validatorStorage._unsorted._cids;

    // delete the previous rotating validator set
    delete $sortedValidatorStorage._rotatingValidators;

    // save the non-rotating validators
    $sortedValidatorStorage._nonRotatingValidators = nonRotatingValidators;

    emit ValidatorSetSaved(period, false, nRV, nonRotatingValidators, rotatingValidators, rotatingStakeAmounts);

    if (nRV == 0) return;

    $sortedValidatorStorage._nRV = uint16(nRV);

    // pack `rotatingValidators` and `rotatingStakeAmounts` into `RotatingValidatorStorage` struct (which cost 1 slot) each to save gas
    // max cap of RON is 1 billion, so using 96 bits (can present up to ~80 billion) for storing stake amount are enough
    uint96[] memory narrowingCastingStakeAmounts = rotatingStakeAmounts.unsafeToUint96s();
    uint256 length = rotatingValidators.length;
    RotatingValidatorStorage memory rv;

    for (uint256 i; i < length; ++i) {
      rv._cid = rotatingValidators[i];
      rv._staked = narrowingCastingStakeAmounts[i];
      $sortedValidatorStorage._rotatingValidators.push(rv);
    }
  }

  /**
   * @dev Returns the set of validators for a given period and epoch.
   */
  function pickValidatorSet(uint256 epoch, uint256 beacon) internal view returns (address[] memory pickedValidatorIds) {
    ValidatorStorage storage $ = _getValidatorPerPeriodLocation();
    UnsortedValidatorStorage storage $unsortedValidatorStorage = $._unsorted;

    if ($._pickAll) return $unsortedValidatorStorage._cids;
    SortedValidatorStorage storage $sortedValidatorStorage = $._sorted;

    // Non Rotating Validators are GVs + SVs
    address[] memory nonRotatingValidators = $sortedValidatorStorage._nonRotatingValidators;

    uint256 nRV = $sortedValidatorStorage._nRV;
    // Skip if num rotating validator required is 0
    if (nRV == 0) return nonRotatingValidators;

    RotatingValidatorStorage[] memory packedRVs = $sortedValidatorStorage._rotatingValidators;
    address[] memory pickedRotatingValidators = _pickTopKRotatingValidatorsByBeaconWeight(packedRVs, nRV, beacon, epoch);

    pickedValidatorIds = nonRotatingValidators.concat(pickedRotatingValidators);
  }

  /**
   * @dev Picks the top `k` rotating validators based on their corresponding beacon weight.
   */
  function _pickTopKRotatingValidatorsByBeaconWeight(
    RotatingValidatorStorage[] memory packedRVs,
    uint256 k,
    uint256 beacon,
    uint256 epoch
  ) private pure returns (address[] memory rotatingValidators) {
    uint256 length = packedRVs.length;
    rotatingValidators = new address[](length);
    uint256[] memory weights = new uint256[](length);

    address id;
    uint256 weight;
    uint256 staked;
    uint256 ptr;

    assembly ("memory-safe") {
      // load the free memory pointer
      ptr := mload(0x40)
      // pre store the beacon value since it is used in the loop
      mstore(ptr, beacon)
      // pre store the epoch value since it is used in the loop
      mstore(add(ptr, 0x20), epoch)
      // update the free memory pointer
      //    ptr + 0x00 = beacon
      //    ptr + 0x20 = epoch
      //    ptr + 0x40 = id
      // => ptr + 0x60 = new_free_memory_pointer
      mstore(0x40, add(ptr, 0x60))
    }

    for (uint256 i; i < length; ++i) {
      id = packedRVs[i]._cid;
      rotatingValidators[i] = id;
      staked = packedRVs[i]._staked;

      assembly ("memory-safe") {
        mstore(add(ptr, 0x40), id)

        // hash the beacon, epoch, and id
        let h := keccak256(ptr, 0x60)
        // split the hash into two 128-bit numbers
        // mask the lower 128 bits
        let h1 := and(h, 0xffffffffffffffffffffffffffffffff)
        // shift the hash to the right by 128 bits
        let h2 := shr(128, h)
        // divide the staked amount by 10**18
        let s := div(staked, 0xde0b6b3a7640000)

        weight := mul(mul(s, s), xor(h1, h2))
      }

      weights[i] = weight;
    }

    rotatingValidators = rotatingValidators.pickTopKByValues(weights, k);
  }

  /**
   * @dev Private function to get the storage location of the sorted validator mapping.
   * @return $ The storage mapping for the sorted validator.
   */
  function _getValidatorPerPeriodLocation() private pure returns (ValidatorStorage storage $) {
    assembly ("memory-safe") {
      $.slot := $$_SortedValidatorByBeaconStorageLocation
    }
  }
}

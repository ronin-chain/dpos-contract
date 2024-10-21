// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibArray } from "src/libraries/LibArray.sol";
import { IndexMap, LibIndexMap } from "src/libraries/LibIndexMap.sol";
import { nonZeroTrustedWeightFilter, notInIndexMapFilter } from "src/utils/Filters.sol";

library LibSortValidatorsByBeaconOld {
  using LibArray for uint256[];
  using LibArray for address[];

  /// @dev value is equal to keccak256(abi.encode(uint256(keccak256("@ronin.RandomBeacon.storage.sortedValidatorsByBeacon")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$_SortedValidatorByBeaconStorageLocation =
    0x8593e13447c7ce85611f094407732145bce33e516174eca63d12235f14022600;

  /// @dev The minimum epoch value.
  uint256 internal constant MIN_EPOCH = 1;
  /// @dev The maximum epoch value.
  uint256 internal constant MAX_EPOCH = 144;

  struct SortedValidatorStorage {
    // An array of non-rotating validator addresses.
    address[] _nonRotatingValidators;
    // A mapping of epoch to an array of rotating validator addresses.
    mapping(uint256 epoch => address[]) _rotatingValidators;
  }

  struct UnsortedValidatorStorage {
    // An array of unsorted validator addresses.
    address[] _ids;
  }

  struct ValidatorStorage {
    // A boolean value indicating whether all the validators are picked.
    bool _pickedAll;
    // Use when rotating validators are changed per epoch
    SortedValidatorStorage _sorted;
    // Use when all the validators are saved (when number of validators is less than the sum of nGV, nSV, and nRV)
    UnsortedValidatorStorage _unsorted;
  }

  /**
   * @dev Requests the sort validator set based on the given parameters.
   * @param beacon The beacon value.
   * @param period The period value.
   * @param nGV The number of governance validators.
   * @param nSV The number of standard validators.
   * @param nRV The number of non-standard validators.
   * @param cids The array of validator addresses.
   * @param stakedAmounts The array of validator staked amounts.
   * @param trustedWeights The array of trusted weights for validators.
   */
  function filterAndSaveValidators(
    uint256 beacon,
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
      // if the number of validators is less than the sum of `nGV`, `nSV`, and `nRV`, save all cids
      if (nGV + nSV + nRV >= length) {
        _saveAll(period, cids);
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
      // The number of governance validators is fewer than the maximum governance validator,
      // The remaining number is transferred to standard validator case
      nSV += nGV - gvIndices.length;
      uint256[] memory svIndices = indices.filterByIndexMap(picked, notInIndexMapFilter);
      // pick top `nSV` standard validators
      svIndices = svIndices.pickTopKByValues(stakedAmounts.take(svIndices), nSV);
      // mark the existence of standard validators
      picked.setBatch(svIndices);

      // filter and pick non-standard validators
      uint256[] memory rvIndices = indices.filterByIndexMap(picked, notInIndexMapFilter);

      _saveNonRotatingAndRotatingCids({
        nRV: nRV,
        period: period,
        beacon: beacon,
        nonRotatingValidators: cids.take(gvIndices.concat(svIndices)),
        rotatingValidators: cids.take(rvIndices),
        rotatingStakedAmounts: stakedAmounts.take(rvIndices)
      });
    }
  }

  /**
   * @dev Saves the unsorted IDs for a given period.
   * @param period The period for which the IDs are being saved.
   * @param ids An array of addresses representing the unsorted IDs.
   */
  function _saveAll(uint256 period, address[] memory ids) private {
    ValidatorStorage storage $ = _getValidatorPerPeriodLocation()[period];
    $._pickedAll = true;
    $._unsorted._ids = ids;
  }

  /**
   * @dev Saves the sorted validators for a given period, beacon, and number of non-rotating validators.
   * @param period The period for which the validators are being saved.
   * @param beacon The beacon value associated with the validators.
   * @param nRV The number of non-standard validators.
   * @param nonRotatingValidators An array of addresses representing the non-rotating validators.
   * @param rotatingValidators An array of addresses representing the rotating validators.
   * @param rotatingStakedAmounts An array of stake values corresponding to the rotating validators.
   */
  function _saveNonRotatingAndRotatingCids(
    uint256 period,
    uint256 beacon,
    uint256 nRV,
    address[] memory nonRotatingValidators,
    address[] memory rotatingValidators,
    uint256[] memory rotatingStakedAmounts
  ) private {
    unchecked {
      SortedValidatorStorage storage $ = _getValidatorPerPeriodLocation()[period]._sorted;

      // save the non-rotating validators
      $._nonRotatingValidators = nonRotatingValidators;

      if (nRV == 0) return;

      uint256 length = rotatingValidators.length;
      uint256[] memory weights = new uint256[](length);
      uint256 end = MAX_EPOCH;
      uint256 start = MIN_EPOCH;

      for (uint256 i = start; i <= end; ++i) {
        for (uint256 j; j < length; ++j) {
          weights[j] = _calcWeight(rotatingValidators[j], rotatingStakedAmounts[j], i, beacon);
        }

        rotatingValidators.inplaceDescSortByValue(weights);
        rotatingStakedAmounts.inplaceDescSortByValue(weights);
        // resize the array to nRV
        rotatingValidators.unsafeResize(nRV);
        rotatingStakedAmounts.unsafeResize(nRV);

        $._rotatingValidators[i] = rotatingValidators;

        // restore the original length
        rotatingStakedAmounts.unsafeResize(length);
        rotatingValidators.unsafeResize(length);
      }
    }
  }

  /**
   * @dev Returns the set of validators for a given period and epoch.
   */
  function pickValidatorSet(uint256 period, uint256 epoch) internal view returns (address[] memory pickedValidatorIds) {
    ValidatorStorage storage $ = _getValidatorPerPeriodLocation()[period];
    if ($._pickedAll) return $._unsorted._ids;
    return $._sorted._nonRotatingValidators.concat($._sorted._rotatingValidators[epoch]);
  }

  /**
   * @dev Calculates the weight of a given ID based on staked amount, epoch, and beacon.
   * @param id The address of the ID.
   * @param staked The amount staked by the ID.
   * @param epoch The epoch value.
   * @param beacon The beacon value.
   * @return weight The calculated weight.
   */
  function _calcWeight(address id, uint256 staked, uint256 epoch, uint256 beacon) private pure returns (uint256 weight) {
    assembly ("memory-safe") {
      // load the free memory pointer
      let ptr := mload(0x40)

      mstore(ptr, beacon)
      mstore(add(ptr, 32), epoch)
      mstore(add(ptr, 64), id)

      // hash the beacon, epoch, and id
      let h := keccak256(ptr, 96)
      // split the hash into two 128-bit numbers
      // mask the lower 128 bits
      let h1 := and(h, 0xffffffffffffffffffffffffffffffff)
      // shift the hash to the right by 128 bits
      let h2 := shr(128, h)
      // divide the staked amount by 10**18
      let s := div(staked, 0xde0b6b3a7640000)

      weight := mul(mul(s, s), xor(h1, h2))
    }
  }

  /**
   * @dev Private function to get the storage location of the sorted validator mapping.
   * @return $ The storage mapping for the sorted validator.
   */
  function _getValidatorPerPeriodLocation()
    private
    pure
    returns (mapping(uint256 period => ValidatorStorage) storage $)
  {
    assembly ("memory-safe") {
      $.slot := $$_SortedValidatorByBeaconStorageLocation
    }
  }
}

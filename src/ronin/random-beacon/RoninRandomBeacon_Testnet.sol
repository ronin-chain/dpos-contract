// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./RoninRandomBeacon.sol";

contract RoninRandomBeacon_Testnet is RoninRandomBeacon {
  /// @dev Emitted when migrate data from the previous version storage slot.
  event Migrated(LibSortValidatorsByBeacon.ValidatorStorage curr);

  function initializeV2() external reinitializer(2) { }

  function initializeV3() external reinitializer(3) {
    LibSortValidatorsByBeacon.ValidatorStorage storage prev =
      LibSortValidatorsByBeacon.getStorageAt(LibSortValidatorsByBeacon.$$_SortedValidatorByBeaconStorageLocation);

    uint256 periodToCopy = _computePeriod(block.timestamp);
    LibSortValidatorsByBeacon.ValidatorStorage storage curr =
      LibSortValidatorsByBeacon.getValidatorPerPeriodLocation({ period: periodToCopy });

    curr._pickAll = prev._pickAll;
    curr._unsorted = prev._unsorted;
    curr._sorted._nRV = prev._sorted._nRV;
    curr._sorted._nonRotatingValidators = prev._sorted._nonRotatingValidators;

    uint256 length = prev._sorted._rotatingValidators.length;

    for (uint256 i; i < length; ++i) {
      curr._sorted._rotatingValidators.push(prev._sorted._rotatingValidators[i]);
    }

    bytes32 prevDataHash = keccak256(abi.encode(prev));
    require(
      prevDataHash == keccak256(abi.encode(curr))
        && prevDataHash == keccak256(abi.encode(this.getSavedValidatorSet(periodToCopy))),
      "[RoninRandomBeacon]: Migrating data failure"
    );

    uint256 nextEpoch = ITimingInfo(getContract(ContractType.VALIDATOR)).epochOf(block.number) + 1;
    require(
      this.getSelectedValidatorSet(periodToCopy, nextEpoch).length != 0,
      "[RoninRandomBeacon]: getSelectedValidatorSet failed"
    );

    emit Migrated(curr);
  }
}

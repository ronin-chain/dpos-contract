// SPDX-License-Identifier: MIT

import "../../interfaces/IProfile.sol";

import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ContractType } from "../../utils/ContractType.sol";
import "./ProfileHandler.sol";

pragma solidity ^0.8.9;

abstract contract ProfileXComponents is IProfile, ProfileHandler {
  /**
   * @inheritdoc IProfile
   */
  function execCreateRollup(address id, uint32 rollupId) external onlyContract(ContractType.ZK_ROLLUP_MANAGER) {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);

    _requireNotOnRenunciation(id);

    if (rollupId == 0) revert ErrZeroRollupId(id);
    if (_profile.id == address(0)) revert ErrNonExistentProfile();
    if (_profile.rollupId != 0) revert ErrExistentRollup(id, _profile.rollupId);

    // Based on `RoninZkEVMRollupManager` contract, the `rollupId` is unique non-zero and incremental.
    // We don't need to check the uniqueness of the `rollupId` here.
    _profile.rollupId = rollupId;
    // By default, the aggregator and sequencer are the same as the profile id.
    _setAggregator(_profile, id);
    _setSequencer(_profile, id);

    emit RollupCreated(id, rollupId);
  }

  /**
   * @inheritdoc IProfile
   */
  function execApplyValidatorCandidate(
    address admin,
    address id,
    address treasury,
    bytes calldata pubkey,
    bytes calldata proofOfPossession
  ) external override onlyContract(ContractType.STAKING) {
    // Check existent profile
    CandidateProfile storage _profile = _id2Profile[id];
    if (_profile.id != address(0)) revert ErrExistentProfile();

    // Validate the info and add the profile
    CandidateProfile memory profile = CandidateProfile({
      id: id,
      consensus: TConsensus.wrap(id),
      admin: admin,
      treasury: payable(treasury),
      __reservedGovernor: address(0),
      pubkey: pubkey,
      profileLastChange: 0,
      oldPubkey: "",
      oldConsensus: TConsensus.wrap(address(0)),
      registeredAt: block.timestamp,
      vrfKeyHash: 0x0,
      vrfKeyHashLastChange: 0,
      rollupId: 0,
      aggregator: address(0),
      sequencer: address(0)
    });

    _requireNonDuplicatedInRegistry(profile);
    _verifyPubkey(pubkey, proofOfPossession);
    _addNewProfile(_profile, profile);
  }

  /**
   * @inheritdoc IProfile
   */
  function arePublicKeysRegistered(
    bytes[][2] calldata listOfPublicKey
  ) external view returns (bool) {
    for (uint256 i; i < listOfPublicKey.length;) {
      for (uint256 j; j < listOfPublicKey[i].length;) {
        if (!_isRegisteredPubkey(listOfPublicKey[i][j])) {
          return false;
        }

        unchecked {
          j++;
        }
      }

      unchecked {
        i++;
      }
    }

    return true;
  }
}

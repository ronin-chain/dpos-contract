// SPDX-License-Identifier: MIT

import "../../interfaces/IProfile.sol";
import { ContractType } from "../../utils/ContractType.sol";
import "./ProfileHandler.sol";

pragma solidity ^0.8.9;

abstract contract ProfileXComponents is IProfile, ProfileHandler {
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
      oldConsensus: TConsensus.wrap(address(0))
    });
    _requireNonDuplicatedInRegistry(profile);
    _verifyPubkey(pubkey, proofOfPossession);
    _addNewProfile(_profile, profile);
  }

  /**
   * @inheritdoc IProfile
   */
  function arePublicKeysRegistered(bytes[][2] calldata listOfPublicKey) external view returns (bool) {
    for (uint i; i < listOfPublicKey.length;) {
      for (uint j; j < listOfPublicKey[i].length;) {
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../udvts/Types.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../utils/RoleAccess.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";

abstract contract ProfileStorage is IProfile, HasContracts {
  /// @dev Mapping from id address => candidate profile.
  mapping(address => CandidateProfile) internal _id2Profile;

  /**
   * @dev Mapping from any address or keccak256(pubkey) => whether it is already registered.
   * This registry can only be toggled to `true` and NOT vice versa. All registered values
   * cannot be reused.
   */
  mapping(uint256 => bool) internal _registry;

  /// @dev Mapping from consensus address => id address.
  mapping(TConsensus => address) internal _consensus2Id;

  /// @dev The cooldown time to change any info in the profile.
  uint256 internal _profileChangeCooldown;

  /// @dev Upgradeable gap.
  bytes32[47] __gap;

  /**
   * @dev Add a profile from memory to storage.
   */
  function _addNewProfile(CandidateProfile storage _profile, CandidateProfile memory newProfile) internal {
    _profile.id = newProfile.id;
    _profile.registeredAt = newProfile.registeredAt;

    _setConsensus(_profile, newProfile.consensus);
    _setAdmin(_profile, newProfile.admin);
    _setTreasury(_profile, newProfile.treasury);
    _setGovernor(_profile, newProfile.__reservedGovernor);
    _setPubkey(_profile, newProfile.pubkey);
    _setVRFKeyHash(_profile, newProfile.vrfKeyHash);

    emit ProfileAdded(newProfile.id);
  }

  function _setConsensus(CandidateProfile storage _profile, TConsensus consensus) internal {
    // Backup old consensus
    _profile.oldConsensus = _profile.consensus;

    // Delete old consensus in mapping
    delete _consensus2Id[_profile.consensus];
    _consensus2Id[consensus] = _profile.id;

    // Set new consensus
    _profile.consensus = consensus;
    _registry[uint256(uint160(TConsensus.unwrap(consensus)))] = true;

    emit ProfileAddressChanged(_profile.id, RoleAccess.CONSENSUS, TConsensus.unwrap(consensus));
  }

  function _setAdmin(CandidateProfile storage _profile, address admin) internal {
    _profile.admin = admin;
    _registry[uint256(uint160(admin))] = true;

    emit ProfileAddressChanged(_profile.id, RoleAccess.CANDIDATE_ADMIN, admin);
  }

  function _setTreasury(CandidateProfile storage _profile, address payable treasury) internal {
    _profile.treasury = treasury;
    _registry[uint256(uint160(address(treasury)))] = true;

    emit ProfileAddressChanged(_profile.id, RoleAccess.TREASURY, treasury);
  }

  /**
   * @dev Allow to registry a profile without governor address since not all validators are governing validators.
   */
  function _setGovernor(CandidateProfile storage _profile, address governor) internal {
    _profile.__reservedGovernor = governor;
    if (governor != address(0)) {
      _registry[uint256(uint160(governor))] = true;
    }
  }

  function _setPubkey(CandidateProfile storage _profile, bytes memory pubkey) internal {
    if (_profile.pubkey.length != 0) {
      _profile.oldPubkey = _profile.pubkey;
    }

    _profile.pubkey = pubkey;
    _registry[_hashPubkey(pubkey)] = true;

    emit PubkeyChanged(_profile.id, pubkey);
  }

  /**
   * @dev Set VRF Key Hash for the profile.
   */
  function _setVRFKeyHash(CandidateProfile storage _profile, bytes32 vrfKeyHash) internal {
    //  Prevent reverting or registering null vrf key hash in `registry`,
    //  in case normal candidate register for their profile,
    //  since only Governing Validator can utilize VRF Key Hash
    if (vrfKeyHash == bytes32(0x0)) return;

    _profile.vrfKeyHash = vrfKeyHash;
    _registry[uint256(vrfKeyHash)] = true;
    _profile.vrfKeyHashLastChange = block.timestamp;

    emit VRFKeyHashChanged(_profile.id, vrfKeyHash);
  }

  function _startCooldown(CandidateProfile storage _profile) internal {
    _profile.profileLastChange = block.timestamp;
  }

  /**
   * @dev Get an existed profile struct from `id`. Revert if the profile does not exists.
   */
  function _getId2ProfileHelper(address id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (_profile.id == address(0)) revert ErrNonExistentProfile();
  }

  /**
   * @dev Returns hash of a public key.
   */
  function _hashPubkey(bytes memory pubkey) internal pure returns (uint256) {
    return uint256(keccak256(pubkey));
  }

  function _setCooldownConfig(uint256 cooldown) internal {
    _profileChangeCooldown = cooldown;
  }
}

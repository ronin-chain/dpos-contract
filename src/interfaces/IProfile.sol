// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TConsensus, TPoolId } from "../udvts/Types.sol";
import "../utils/RoleAccess.sol";

interface IProfile {
  struct CandidateProfile {
    /**
     * @dev Primary key of the profile, use for backward querying.
     *
     * {Staking} Contract: index of pool
     * {RoninValidatorSet} Contract: index of almost all data related to a validator
     *
     */
    address id;
    /// @dev Consensus address.
    TConsensus consensus;
    /// @dev Validator’s admin address.
    address admin;
    /// @dev Treasury address.
    address payable treasury;
    /// @dev Address to voting proposal.
    address __reservedGovernor;
    /// @dev Public key for fast finality.
    bytes pubkey;
    /// @dev Timestamp of last change of any profile info.
    uint256 profileLastChange;
    /// @dev Old public key for fast finality.
    bytes oldPubkey;
    /// @dev Old consensus
    TConsensus oldConsensus;
    /// @dev Timestamp where the profile is registered.
    uint256 registeredAt;
    /// @dev VRF key hash for the profile.
    bytes32 vrfKeyHash;
    /// @dev Timestamp of last change of VRF key hash. Only used in the logic of Beacon. Not used for checking for cooldown of updating the profile.
    uint256 vrfKeyHashLastChange;
  }

  /// @dev Event emitted when a profile with `id` is added.
  event ProfileAdded(address indexed id);
  /// @dev Event emitted when the profile is migrated (mostly when REP-4 update).
  event ProfileMigrated(address indexed id, address indexed admin, address indexed treasury);
  /// @dev Event emitted when a address in a profile is changed.
  event ProfileAddressChanged(address indexed id, RoleAccess indexed addressType, address indexed addr);
  /// @dev Event emitted when the consensus of a non-governor profile is changed.
  event ConsensusAddressOfNonGovernorChanged(address indexed id);
  /// @dev Event emitted when the pubkey of the `id` is changed.
  event PubkeyChanged(address indexed id, bytes pubkey);
  /// @dev Event emitted when the VRF key hash of the `id` is changed.
  event VRFKeyHashChanged(address indexed id, bytes32 vrfKeyHash);
  /// @dev Event emitted when the pubkey is verified successfully.
  event PubkeyVerified(bytes pubkey, bytes proofOfPossession);

  /// @dev Error of already existed profile.
  error ErrExistentProfile();
  /// @dev Error of non existed profile.
  error ErrNonExistentProfile();
  /// @dev Error when create a new profile whose id and consensus are not identical.
  error ErrIdAndConsensusDiffer();
  /// @dev Error when failed to change any address or pubkey in the profile because cooldown is not ended.
  error ErrProfileChangeCooldownNotEnded();
  /**
   * @dev Error when there is a duplicated info of `value`, which is uin256-padding value of any address or hash of public key,
   * and with value type of `infoType`.
   */
  error ErrDuplicatedInfo(RoleAccess infoType, uint256 value);
  error ErrDuplicatedPubkey(bytes pubkey);
  error ErrZeroAddress(RoleAccess infoType);
  error ErrDuplicatedVRFKeyHash(bytes32 vrfKeyHash);
  error ErrZeroPubkey();
  error ErrInvalidProofOfPossession(bytes pubkey, bytes proofOfPossession);
  error ErrLookUpIdFailed(TConsensus consensus);
  error ErrLookUpIdFromVRFKeyFailed(bytes32 vrfKeyHash);
  error ErrValidatorOnRenunciation(address cid);

  function initialize(
    address validatorContract
  ) external;

  function initializeV2(address stakingContract, address trustedOrgContract) external;

  function initializeV3(
    uint256 cooldown
  ) external;

  /// @dev Getter to query full `profile` from `id` address.
  function getId2Profile(
    address id
  ) external view returns (CandidateProfile memory profile);

  /// @dev Getter to query required random beacon info from `vrfKeyHash`.
  function getVRFKeyHash2BeaconInfo(
    bytes32 vrfKeyHash
  ) external view returns (address id, uint256 vrfKeyHashLastChange, uint256 registeredAt);

  /// @dev Getter to query required random beacon info from `id` address.
  function getId2BeaconInfo(
    address id
  ) external view returns (bytes32 vrfKeyHash, uint256 vrfKeyHashLastChange, uint256 registeredAt);

  /// @dev Getter to query `admin` from `id` address.
  function getId2Admin(
    address id
  ) external view returns (address);

  /// @dev Getter to query `treasury` from `id` address.
  function getId2Treasury(
    address id
  ) external view returns (address payable);

  /// @dev Getter to query `pubkey` from `id` address.
  function getId2Pubkey(
    address id
  ) external view returns (bytes memory);

  /// @dev Getter to query `profileLastChange` from `id` address.
  function getId2ProfileLastChange(
    address id
  ) external view returns (uint256);

  /// @dev Getter to query `oldPubkey` from `id` address.
  function getId2OldPubkey(
    address id
  ) external view returns (bytes memory);

  /// @dev Getter to query `oldConsensus` from `id` address.
  function getId2OldConsensus(
    address id
  ) external view returns (TConsensus);

  /// @dev Getter to query `registeredAt` from `id` address.
  function getId2RegisteredAt(
    address id
  ) external view returns (uint256);

  /// @dev Getter to query `consensus` from `id` address.
  function getId2Consensus(
    address id
  ) external view returns (TConsensus);

  /// @dev Getter to query `vrfKeyHash` from `id` address.
  function getId2VRFKeyHash(
    address id
  ) external view returns (bytes32);

  /// @dev Getter to query `vrfKeyHashLastChange` from `id` address.
  function getId2VRFKeyHashLastChange(
    address id
  ) external view returns (uint256);

  /// @dev Getter to batch query from `id` to `registeredAt`.
  function getManyId2RegisteredAt(
    address[] calldata idList
  ) external view returns (uint256[] memory);

  /// @dev Getter to batch query from `id` to `admin`, return address(0) if the profile not exist.
  function getManyId2Admin(
    address[] calldata idList
  ) external view returns (address[] memory);

  /// @dev Getter to batch query from `id` to `consensus`, return address(0) if the profile not exist.
  function getManyId2Consensus(
    address[] calldata idList
  ) external view returns (TConsensus[] memory consensusList);

  /// @dev Getter to backward query from `consensus` address to `id` address, revert if not found.
  function getConsensus2Id(
    TConsensus consensus
  ) external view returns (address id);

  /// @dev Getter to backward query from `vrfKeyHash` to `id` address, revert if not found.
  function getVRFKeyHash2Id(
    bytes32 vrfKeyHash
  ) external view returns (address id);

  /// @dev Getter to backward query from `consensus` address to `id` address.
  function tryGetConsensus2Id(
    TConsensus consensus
  ) external view returns (bool found, address id);

  /// @dev Getter to backward query from `vrfKeyHash` to `id` address.
  function tryGetVRFKeyHash2Id(
    bytes32 vrfKeyHash
  ) external view returns (bool found, address id);

  /// @dev Getter to backward batch query from `consensus` address to `id` address.
  function getManyConsensus2Id(
    TConsensus[] memory consensus
  ) external view returns (address[] memory);

  /**
   * @dev Cross-contract function to add/update new profile of a validator candidate when they
   * applying for candidate role.
   *
   * Requirements:
   * - Only `stakingContract` can call this method.
   */
  function execApplyValidatorCandidate(
    address admin,
    address id,
    address treasury,
    bytes calldata pubkey,
    bytes calldata proofOfPossession
  ) external;

  /**
   * @dev Updated the treasury address of candidate id `id` immediately without waiting time.
   *
   * Emit an {ProfileAddressChanged}.
   */
  function changeAdminAddr(address id, address newAdminAddr) external;

  /**
   * @dev Updated the treasury address of candidate id `id` immediately without waiting time.
   *
   * Emit an {ProfileAddressChanged}.
   */
  function changeConsensusAddr(address id, TConsensus newConsensusAddr) external;

  /**
   * @dev Updated the treasury address of candidate id `id` immediately without waiting time.
   *
   * Emit an {ProfileAddressChanged}.
   */
  function changeTreasuryAddr(address id, address payable newTreasury) external;

  /**
   * @notice The candidate admin changes the public key.
   *
   * @dev Requirements:
   * - The profile must be existed.
   * - Only user with candidate admin role can call this method.
   * - New public key must not be duplicated.
   * - The proof of public key possession must be verified successfully.
   * - The public key change cooldown must be ended.
   */
  function changePubkey(address id, bytes memory pubkey, bytes memory proofOfPossession) external;

  /**
   * @notice The candidate admin changes the VRF key hash.
   *
   * @dev Requirements:
   * - The profile must be existed.
   * - Only user with candidate admin role can call this method.
   * - New VRF key hash must not be duplicated.
   * - The VRF key hash change cooldown must be ended.
   */
  function changeVRFKeyHash(address id, bytes32 vrfKeyHash) external;

  /**
   * @dev Cross-contract function to for slash indicator to check the list of public
   * keys in finality slash proof
   *
   * Returns whether all public keys are registered.
   */
  function arePublicKeysRegistered(
    bytes[][2] calldata listOfPublicKey
  ) external view returns (bool);

  /**
   * @dev Change the cooldown between 2 public key change
   *
   * Requirement:
   *  - Only admin can call this method
   */
  function setCooldownConfig(
    uint256 cooldown
  ) external;

  /**
   * @dev Returns the config of cool down on change profile info.
   */
  function getCooldownConfig() external view returns (uint256);
}

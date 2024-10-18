// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IProfile.sol";
import "./ProfileXComponents.sol";
import { ErrUnauthorized, RoleAccess } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";

contract Profile is IProfile, ProfileXComponents, Initializable {
  constructor() {
    _disableInitializers();
  }

  // Pre-hook of `changeConsensusAddr` method, where this method is revert on mainnet, until it fully integrated with other components.
  modifier hookChangeConsensus() virtual {
    _;
  }

  function initialize(
    address validatorContract
  ) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function initializeV2(address stakingContract, address trustedOrgContract) external reinitializer(2) {
    _setContract(ContractType.STAKING, stakingContract);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, trustedOrgContract);

    TConsensus[] memory validatorCandidates =
      IRoninValidatorSet(getContract(ContractType.VALIDATOR)).getValidatorCandidates();

    for (uint256 i; i < validatorCandidates.length; ++i) {
      TConsensus consensus = validatorCandidates[i];
      address id = TConsensus.unwrap(consensus);
      _consensus2Id[consensus] = id;
    }

    __migrationRenouncedCandidates();
  }

  function initializeV3(
    uint256 cooldown
  ) external reinitializer(3) {
    _setCooldownConfig(cooldown);
  }

  /**
   * @dev Add addresses of renounced candidates into registry. Only called during {initializeV2}.
   */
  function __migrationRenouncedCandidates() internal virtual { }

  /**
   * @dev This method is used in REP-4 migration, which creates profile for all community-validators and renounced validators.
   * This method can be removed after REP-4 goes live.
   *
   * DO NOT use for any other purpose.
   */
  function __migrate(address id, address candidateAdmin, address treasury) internal {
    CandidateProfile storage _profile = _id2Profile[id];
    _profile.id = id;

    _setConsensus(_profile, TConsensus.wrap(id));
    _setAdmin(_profile, candidateAdmin);
    _setTreasury(_profile, payable(treasury));
    emit ProfileMigrated(id, candidateAdmin, treasury);
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2Profile(
    address id
  ) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2BeaconInfo(
    address id
  ) external view returns (bytes32 vrfKeyHash, uint256 vrfKeyHashLastChange, uint256 registeredAt) {
    CandidateProfile storage $ = _getId2ProfileHelper(id);

    vrfKeyHash = $.vrfKeyHash;
    registeredAt = $.registeredAt;
    vrfKeyHashLastChange = $.vrfKeyHashLastChange;
  }

  /**
   * @inheritdoc IProfile
   */
  function getVRFKeyHash2BeaconInfo(
    bytes32 vrfKeyHash
  ) external view returns (address id, uint256 vrfKeyHashLastChange, uint256 registeredAt) {
    id = _getVRFKeyHash2Id(vrfKeyHash);
    CandidateProfile storage $ = _getId2ProfileHelper(id);

    registeredAt = $.registeredAt;
    vrfKeyHashLastChange = $.vrfKeyHashLastChange;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2Admin(
    address id
  ) external view returns (address) {
    return _id2Profile[id].admin;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2Treasury(
    address id
  ) external view returns (address payable) {
    return _id2Profile[id].treasury;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2Pubkey(
    address id
  ) external view returns (bytes memory) {
    return _id2Profile[id].pubkey;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2ProfileLastChange(
    address id
  ) external view returns (uint256) {
    return _id2Profile[id].profileLastChange;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2OldPubkey(
    address id
  ) external view returns (bytes memory) {
    return _id2Profile[id].oldPubkey;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2OldConsensus(
    address id
  ) external view returns (TConsensus) {
    return _id2Profile[id].oldConsensus;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2RegisteredAt(
    address id
  ) external view returns (uint256) {
    return _id2Profile[id].registeredAt;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2VRFKeyHashLastChange(
    address id
  ) external view returns (uint256) {
    return _id2Profile[id].vrfKeyHashLastChange;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2Consensus(
    address id
  ) external view returns (TConsensus) {
    return _id2Profile[id].consensus;
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2VRFKeyHash(
    address id
  ) external view returns (bytes32) {
    return _id2Profile[id].vrfKeyHash;
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyId2Admin(
    address[] calldata idList
  ) external view returns (address[] memory adminList) {
    adminList = new address[](idList.length);

    for (uint i; i < idList.length; ++i) {
      adminList[i] = _id2Profile[idList[i]].admin;
    }
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyId2Consensus(
    address[] calldata idList
  ) external view returns (TConsensus[] memory consensusList) {
    consensusList = new TConsensus[](idList.length);
    for (uint i; i < idList.length; ++i) {
      consensusList[i] = _id2Profile[idList[i]].consensus;
    }
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyId2RegisteredAt(
    address[] calldata idList
  ) external view returns (uint256[] memory registeredAtList) {
    uint256 length = idList.length;
    registeredAtList = new uint256[](length);

    for (uint256 i; i < length; ++i) {
      registeredAtList[i] = _id2Profile[idList[i]].registeredAt;
    }
  }

  /**
   * @inheritdoc IProfile
   */
  function getConsensus2Id(
    TConsensus consensus
  ) external view returns (address) {
    return _getConsensus2Id(consensus);
  }

  /**
   * @inheritdoc IProfile
   */
  function getVRFKeyHash2Id(
    bytes32 vrfKeyHash
  ) external view returns (address) {
    return _getVRFKeyHash2Id(vrfKeyHash);
  }

  /**
   * @inheritdoc IProfile
   */
  function tryGetVRFKeyHash2Id(
    bytes32 vrfKeyHash
  ) external view returns (bool found, address id) {
    return _tryGetVRFKeyHash2Id(vrfKeyHash);
  }

  /**
   * @dev Look up the `id` by `consensus`, revert if not found.
   */
  function _getConsensus2Id(
    TConsensus consensus
  ) internal view returns (address) {
    (bool found, address id) = _tryGetConsensus2Id(consensus);
    if (!found) revert ErrLookUpIdFailed(consensus);
    return id;
  }

  /**
   * @dev Look up the `id` by `vrfKeyHash`, revert if not found.
   */
  function _getVRFKeyHash2Id(
    bytes32 vrfKeyHash
  ) internal view returns (address) {
    (bool found, address id) = _tryGetVRFKeyHash2Id(vrfKeyHash);
    if (!found) revert ErrLookUpIdFromVRFKeyFailed(vrfKeyHash);
    return id;
  }

  /**
   * @inheritdoc IProfile
   */
  function tryGetConsensus2Id(
    TConsensus consensus
  ) external view returns (bool found, address id) {
    return _tryGetConsensus2Id(consensus);
  }

  /**
   * @dev Try look up the `id` by `consensus`, return a boolean indicating whether the query success.
   */
  function _tryGetConsensus2Id(
    TConsensus consensus
  ) internal view returns (bool found, address id) {
    id = _consensus2Id[consensus];
    found = id != address(0);
  }

  /**
   * @dev Try Look up the `id` by `vrfKeyHash`, return a boolean indicating whether the query success.
   */
  function _tryGetVRFKeyHash2Id(
    bytes32 vrfKeyHash
  ) internal view returns (bool found, address id) {
    id = _vrfKeyHash2Id[vrfKeyHash];
    found = id != address(0);
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyConsensus2Id(
    TConsensus[] calldata consensusList
  ) external view returns (address[] memory idList) {
    idList = new address[](consensusList.length);
    unchecked {
      for (uint i; i < consensusList.length; ++i) {
        idList[i] = _getConsensus2Id(consensusList[i]);
      }
    }
  }

  /**
   * @inheritdoc IProfile
   *
   * @dev Side-effects on other contracts:
   * - Update Staking contract:
   *    + [x] Update (id => PoolDetail) mapping in {BaseStaking.sol}.
   *    + [x] Update `_adminOfActivePoolMapping` in {BaseStaking.sol}.
   *    + [x] Move staking amount of previous admin to the the new admin.
   * - Update Validator contract:
   *    + [x] Update (id => ValidatorCandidate) mapping
   *
   * - See other side-effects for treasury in {changeTreasuryAddr}, since treasury and admin must be identical.
   */
  function changeAdminAddr(address id, address newAdminAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonZeroAndNonDuplicated(RoleAccess.CANDIDATE_ADMIN, newAdminAddr);
    _requireCooldownPassedAndStartCooldown(_profile);
    _requireNotOnRenunciation(id);

    IStaking stakingContract = IStaking(getContract(ContractType.STAKING));
    stakingContract.execChangeAdminAddr({ poolId: id, currAdminAddr: msg.sender, newAdminAddr: newAdminAddr });

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    validatorContract.execChangeAdminAddr(id, newAdminAddr);
    validatorContract.execChangeTreasuryAddr(id, payable(newAdminAddr));

    _setAdmin(_profile, newAdminAddr);
    _setTreasury(_profile, payable(newAdminAddr));
  }

  /**
   * @inheritdoc IProfile
   *
   * @dev Side-effects on other contracts:
   * - Update in Staking contract for Consensus address mapping:
   *   + [x] Keep the same previous pool address.
   * - Update in Validator contract for:
   *   + [x] Consensus Address mapping
   *   + [x] Bridge Address mapping
   *   + [x] Jail mapping
   *   + [x] Pending reward mapping
   *   + [x] Schedule mapping
   * - Update in Slashing contract for:
   *   + [x] Handling slash indicator
   *   + [x] Handling slash fast finality
   *   + [x] Handling slash double sign
   * - Update in Proposal contract for:
   *   + [-] Preserve the consensus address and recipient target of locked amount of emergency exit
   * - Update Trusted Org contracts:
   *   + If the current consensus is governor:
   *      - [x] Remove and delete weight of the old consensus
   *      - [x] Replace and add weight for the new consensus
   *   + If the current consensus is not governor:
   *      - [x] Do nothing
   */
  function changeConsensusAddr(address id, TConsensus newConsensusAddr) external hookChangeConsensus {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonZeroAndNonDuplicated(RoleAccess.CONSENSUS, TConsensus.unwrap(newConsensusAddr));
    _requireCooldownPassedAndStartCooldown(_profile);

    TConsensus oldConsensusAddr = _profile.consensus;

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    validatorContract.execChangeConsensusAddr(id, newConsensusAddr);

    address trustedOrgContractAddr = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION);
    (bool success,) = trustedOrgContractAddr.call(
      abi.encodeCall(
        IRoninTrustedOrganization.execChangeConsensusAddressForTrustedOrg, (oldConsensusAddr, newConsensusAddr)
      )
    );

    if (!success) {
      emit ConsensusAddressOfNonGovernorChanged(id);
    }

    _setConsensus(_profile, newConsensusAddr);
  }

  /**
   * @inheritdoc IProfile
   *
   * @notice This method is not supported. Change treasury also requires changing the admin address.
   * Using the {changeAdminAddr} method instead
   *
   * @dev Side-effects on other contracts:
   * - Update Validator contract:
   *    + [x] Update (id => ValidatorCandidate) mapping
   * - Update governance admin:
   *    + [-] Update recipient in the EmergencyExitBallot to the newTreasury.
   *          Cannot impl since we cannot cancel the previous the ballot and
   *          create a new ballot on behalf of the validator contract.
   */
  function changeTreasuryAddr(address, /*id */ address payable /* newTreasury */ ) external pure {
    revert("Not supported");
  }

  /**
   * @inheritdoc IProfile
   */
  function changePubkey(address id, bytes calldata pubkey, bytes calldata proofOfPossession) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonDuplicatedPubkey(pubkey);
    _verifyPubkey(pubkey, proofOfPossession);
    _requireCooldownPassedAndStartCooldown(_profile);
    _setPubkey(_profile, pubkey);
  }

  /**
   * @inheritdoc IProfile
   */
  function changeVRFKeyHash(address id, bytes32 vrfKeyHash) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonDuplicatedVRFKeyHash(vrfKeyHash);
    _requireCooldownPassedAndStartCooldown(_profile);
    _setVRFKeyHash(_profile, vrfKeyHash);
  }

  function _requireCandidateAdmin(
    CandidateProfile storage sProfile
  ) internal view {
    if (
      msg.sender != sProfile.admin
        || !IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdminById(sProfile.id, msg.sender)
    ) revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
  }

  function _requireNotOnRenunciation(
    address id
  ) internal view {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    if (validatorContract.getCandidateInfoById(id).revokingTimestamp > 0) revert ErrValidatorOnRenunciation(id);
  }

  /**
   * @inheritdoc IProfile
   */
  function getCooldownConfig() external view returns (uint256) {
    return _profileChangeCooldown;
  }

  /**
   * @inheritdoc IProfile
   */
  function setCooldownConfig(
    uint256 cooldown
  ) external onlyAdmin {
    _setCooldownConfig(cooldown);
  }
}

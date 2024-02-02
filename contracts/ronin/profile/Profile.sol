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

  function initialize(address validatorContract) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function initializeV2(address stakingContract, address trustedOrgContract) external reinitializer(2) {
    _setContract(ContractType.STAKING, stakingContract);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, trustedOrgContract);

    TConsensus[] memory validatorCandidates = IRoninValidatorSet(getContract(ContractType.VALIDATOR))
      .getValidatorCandidates();

    for (uint256 i; i < validatorCandidates.length; ++i) {
      TConsensus consensus = validatorCandidates[i];
      address id = TConsensus.unwrap(consensus);
      _consensus2Id[consensus] = id;
    }

    __migrationRenouncedCandidates();
  }

  function initializeV3(uint256 cooldown) external reinitializer(3) {
    _setPubkeyChangeCooldown(cooldown);
  }

  /**
   * @dev Add addresses of renounced candidates into registry. Only called during {initializeV2}.
   */
  function __migrationRenouncedCandidates() internal virtual {}

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
  function getId2Profile(address id) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyId2Consensus(address[] calldata idList) external view returns (TConsensus[] memory consensusList) {
    consensusList = new TConsensus[](idList.length);
    unchecked {
      for (uint i; i < idList.length; ++i) {
        consensusList[i] = _id2Profile[idList[i]].consensus;
      }
    }
  }

  /**
   * @inheritdoc IProfile
   */
  function getConsensus2Id(TConsensus consensus) external view returns (address) {
    return _getConsensus2Id(consensus);
  }

  function _getConsensus2Id(TConsensus consensus) internal view returns (address) {
    (bool found, address id) =  _tryGetConsensus2Id(consensus);
    if (!found) revert ErrLookUpIdFailed(consensus);
    return id;
  }

  /**
   * @inheritdoc IProfile
   */
  function tryGetConsensus2Id(TConsensus consensus) external view returns (bool found, address id) {
    return _tryGetConsensus2Id(consensus);
  }

  /**
   * @dev Look up the `id` by `consensus`, revert if not found.
   */
  function _tryGetConsensus2Id(TConsensus consensus) internal view returns (bool found, address id) {
    id = _consensus2Id[consensus];
    found = id != address(0);
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyConsensus2Id(TConsensus[] calldata consensusList) external view returns (address[] memory idList) {
    idList = new address[](consensusList.length);
    unchecked {
      for (uint i; i < consensusList.length; ++i) {
        idList[i] = _getConsensus2Id(consensusList[i]);
      }
    }
  }

  /**
   * @inheritdoc IProfile
   */
  function addNewProfile(CandidateProfile memory profile) external onlyAdmin {
    CandidateProfile storage _profile = _id2Profile[profile.id];
    if (_profile.id != address(0)) revert ErrExistentProfile();
    _addNewProfile(_profile, profile);
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
   * - See other side-effects for treasury in {requestChangeTreasuryAddr}, since treasury and admin must be identical.
   */
  function requestChangeAdminAddress(address id, address newAdminAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonZeroAndNonDuplicated(RoleAccess.CANDIDATE_ADMIN, newAdminAddr);

    IStaking stakingContract = IStaking(getContract(ContractType.STAKING));
    stakingContract.execChangeAdminAddress({ poolId: id, currAdminAddr: msg.sender, newAdminAddr: newAdminAddr });

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    validatorContract.execChangeAdminAddress(id, newAdminAddr);
    validatorContract.execChangeTreasuryAddress(id, payable(newAdminAddr));

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
   *   + [x] Remove and delete weight of the old consensus
   *   + [x] Replace and add weight for the new consensus
   */
  function requestChangeConsensusAddr(address id, TConsensus newConsensusAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonZeroAndNonDuplicated(RoleAccess.CONSENSUS, TConsensus.unwrap(newConsensusAddr));

    TConsensus oldConsensusAddr = _profile.consensus;

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    validatorContract.execChangeConsensusAddress(id, newConsensusAddr);

    IRoninTrustedOrganization trustedOrgContract = IRoninTrustedOrganization(
      getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)
    );
    trustedOrgContract.execChangeConsensusAddressForTrustedOrg({
      oldConsensusAddr: oldConsensusAddr,
      newConsensusAddr: newConsensusAddr
    });

    _setConsensus(_profile, newConsensusAddr);
  }

  /**
   * @inheritdoc IProfile
   *
   * @notice This method is not supported. Change treasury also requires changing the admin address.
   * Using the {requestChangeAdminAddress} method instead
   *
   * @dev Side-effects on other contracts:
   * - Update Validator contract:
   *    + [x] Update (id => ValidatorCandidate) mapping
   * - Update governance admin:
   *    + [-] Update recipient in the EmergencyExitBallot to the newTreasury.
   *          Cannot impl since we cannot cancel the previous the ballot and
   *          create a new ballot on behalf of the validator contract.
   */
  function requestChangeTreasuryAddr(address /*id */, address payable /* newTreasury */) external pure {
    revert("Not supported");
  }

  /**
   * @inheritdoc IProfile
   */
  function changePubkey(address id, bytes calldata pubkey, bytes calldata proofOfPossession) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _requireNonDuplicatedPubkey(pubkey);
    _checkPubkeyChangeCooldown(_profile);
    _verifyPubkey(pubkey, proofOfPossession);
    _setPubkey(_profile, pubkey);
  }

  function _requireCandidateAdmin(CandidateProfile storage sProfile) internal view {
    if (
      msg.sender != sProfile.admin ||
      !IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdminById(sProfile.id, msg.sender)
    ) revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
  }

  /**
   * @inheritdoc IProfile
   */
  function setPubkeyChangeCooldown(uint256 cooldown) external onlyAdmin {
    _setPubkeyChangeCooldown(cooldown);
  }
}

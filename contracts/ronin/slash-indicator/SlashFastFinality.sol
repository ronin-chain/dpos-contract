// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/slash-indicator/ISlashFastFinality.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IProfile } from "../../interfaces/IProfile.sol";
import { IRoninTrustedOrganization } from "../../interfaces/IRoninTrustedOrganization.sol";
import "../../precompile-usages/PCUValidateFastFinality.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../utils/CommonErrors.sol";

abstract contract SlashFastFinality is ISlashFastFinality, HasContracts, PCUValidateFastFinality {
  /// @dev The amount of RON to slash fast finality.
  uint256 internal _slashFastFinalityAmount;
  /// @dev The block number that the punished validator will be jailed until, due to malicious fast finality.
  uint256 internal _fastFinalityJailUntilBlock;
  /// @dev Recording of submitted proof to prevent relay attack.
  mapping(bytes32 => bool) internal _processedEvidence;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[21] private ______gap;

  modifier onlyGoverningValidator() {
    if (_getGovernorWeight(msg.sender) == 0) revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
    _;
  }

  /**
   * @inheritdoc ISlashFastFinality
   */
  function slashFastFinality(
    TConsensus consensusAddr,
    bytes calldata voterPublicKey,
    uint256 targetBlockNumber,
    bytes32[2] calldata targetBlockHash,
    bytes[][2] calldata listOfPublicKey,
    bytes[2] calldata aggregatedSignature
  ) external override onlyGoverningValidator {
    address validatorId = __css2cid(consensusAddr);
    IProfile profileContract = IProfile(getContract(ContractType.PROFILE));

    IProfile.CandidateProfile memory profile = profileContract.getId2Profile(validatorId);
    bytes32 voterPublicKeyHash = keccak256(voterPublicKey);
    if ((voterPublicKeyHash != keccak256(profile.pubkey)) && (voterPublicKeyHash != keccak256(profile.oldPubkey))) {
      revert ErrInvalidArguments(msg.sig);
    }

    bytes32 evidenceHash = keccak256(abi.encodePacked(consensusAddr, targetBlockNumber));
    if (_processedEvidence[evidenceHash]) revert ErrEvidenceAlreadySubmitted();

    if (!profileContract.arePublicKeysRegistered(listOfPublicKey)) {
      revert ErrUnregisteredPublicKey();
    }

    if (
      _pcValidateFastFinalityEvidence(
        voterPublicKey, targetBlockNumber, targetBlockHash, listOfPublicKey, aggregatedSignature
      )
    ) {
      _processedEvidence[evidenceHash] = true;

      IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
      uint256 period = validatorContract.currentPeriod();
      emit Slashed(validatorId, SlashType.FAST_FINALITY, period);
      validatorContract.execSlash({
        cid: validatorId,
        newJailedUntil: _fastFinalityJailUntilBlock,
        slashAmount: _slashFastFinalityAmount,
        cannotBailout: true
      });
    }
  }

  /**
   * @inheritdoc ISlashFastFinality
   */
  function getFastFinalitySlashingConfigs()
    external
    view
    override
    returns (uint256 slashFastFinalityAmount_, uint256 fastFinalityJailUntilBlock_)
  {
    return (_slashFastFinalityAmount, _fastFinalityJailUntilBlock);
  }

  /**
   * @inheritdoc ISlashFastFinality
   */
  function setFastFinalitySlashingConfigs(uint256 slashAmount, uint256 jailUntilBlock) external override onlyAdmin {
    _setFastFinalitySlashingConfigs(slashAmount, jailUntilBlock);
  }

  /**
   * @dev See `ISlashFastFinality-setFastFinalitySlashingConfigs`.
   */
  function _setFastFinalitySlashingConfigs(uint256 slashAmount, uint256 jailUntilBlock) internal {
    _slashFastFinalityAmount = slashAmount;
    _fastFinalityJailUntilBlock = jailUntilBlock;
    emit FastFinalitySlashingConfigsUpdated(slashAmount, jailUntilBlock);
  }

  /**
   * @dev Get governor, i.e. governing validator's weight, of the `addr`.
   */
  function _getGovernorWeight(address addr) internal view returns (uint256) {
    return IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getGovernorWeight(addr);
  }

  function __css2cid(TConsensus consensusAddr) internal view virtual returns (address);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { StdStyle } from "forge-std/StdStyle.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Test, console } from "forge-std/Test.sol";
import { DeployDPoS } from "script/deploy-dpos/DeployDPoS.s.sol";
import { vme } from "@fdk/utils/Constants.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { Contract } from "script/utils/Contract.sol";
import { loadContract } from "@fdk/utils/Helpers.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { ICoinbaseExecution } from "src/interfaces/validator/ICoinbaseExecution.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRandomBeacon } from "src/interfaces/random-beacon/IRandomBeacon.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { GlobalConfigConsumer } from "src/extensions/consumers/GlobalConfigConsumer.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { IProfile } from "src/interfaces/IProfile.sol";
import { LibArray } from "src/libraries/LibArray.sol";
import { LibSortValidatorsByBeacon } from "src/libraries/LibSortValidatorsByBeacon.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { ISlashRandomBeacon } from "src/interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { ISlashIndicator } from "src/interfaces/slash-indicator/ISlashIndicator.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { IBaseSlash } from "src/interfaces/slash-indicator/IBaseSlash.sol";
import { RandomRequest } from "src/libraries/LibSLA.sol";
import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { IStakingVesting } from "src/interfaces/IStakingVesting.sol";
import { IFastFinalityTracking } from "src/interfaces/IFastFinalityTracking.sol";
import { TConsensus } from "src/udvts/Types.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";

contract REP10_BaseTest is Test, GlobalConfigConsumer {
  DeployDPoS dposDeployHelper;
  bytes param;
  IProfile public profile;
  IStaking public staking;
  IRoninGovernanceAdmin governanceAdmin;
  IStakingVesting public stakingVesting;
  ISlashIndicator public slashIndicator;
  IRandomBeacon public roninRandomBeacon;
  IRoninValidatorSet public roninValidatorSet;
  IFastFinalityTracking public fastFinalityTracking;
  IRoninTrustedOrganization public roninTrustedOrganization;

  function setUp() public virtual {
    _setUpDPoSDeployHelper();
    _loadContracts();

    dposDeployHelper.cheatSetUpValidators();

    _cheatTime();
  }

  function _cheatTime() internal virtual {
    vm.warp(_bound(vm.getBlockTimestamp(), vm.unixTime() / 1_000, type(uint40).max));
    vme.rollUpTo(1000);

    LibWrapUpEpoch.wrapUpEpoch();

    uint256 currPeriod = _computePeriod(vm.getBlockTimestamp());
    uint256 rep10ActivationPeriod = ISharedArgument(address(vme)).sharedArguments().roninRandomBeacon.activatedAtPeriod;
    LibWrapUpEpoch.wrapUpPeriods({ times: rep10ActivationPeriod - currPeriod, shouldSubmitBeacon: false });
  }

  function _loadContracts() internal virtual {
    profile = IProfile(loadContract(Contract.Profile.key(), true));
    staking = IStaking(loadContract(Contract.Staking.key(), true));
    stakingVesting = IStakingVesting(loadContract(Contract.StakingVesting.key(), true));
    slashIndicator = ISlashIndicator(loadContract(Contract.SlashIndicator.key(), true));
    roninRandomBeacon = IRandomBeacon(loadContract(Contract.RoninRandomBeacon.key(), true));
    roninValidatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key(), true));
    governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key(), true));
    fastFinalityTracking = IFastFinalityTracking(loadContract(Contract.FastFinalityTracking.key(), true));
    roninTrustedOrganization = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key(), true));
  }

  function _setUpDPoSDeployHelper() internal virtual {
    dposDeployHelper = new DeployDPoS();
    dposDeployHelper.setUp();
    param = vme.getRawSharedArguments();
    dposDeployHelper.run();
    LibPrecompile.deployPrecompile();
  }

  /**
   * @dev See {TimingStorage-_computePeriod}.
   *
   * This duplicates the implementation in {RoninValidatorSet-_computePeriod} to reduce external calls.
   */
  function _computePeriod(uint256 timestamp) internal pure returns (uint256) {
    return timestamp / PERIOD_DURATION;
  }
}

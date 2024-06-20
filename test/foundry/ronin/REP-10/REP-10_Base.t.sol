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
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { GlobalConfigConsumer } from "@ronin/contracts/extensions/consumers/GlobalConfigConsumer.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { LibArray } from "@ronin/contracts/libraries/LibArray.sol";
import { LibSortValidatorsByBeacon } from "@ronin/contracts/libraries/LibSortValidatorsByBeacon.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { ISlashRandomBeacon } from "@ronin/contracts/interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { IBaseSlash } from "@ronin/contracts/interfaces/slash-indicator/IBaseSlash.sol";
import { RandomRequest } from "@ronin/contracts/libraries/LibSLA.sol";
import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { IStakingVesting } from "@ronin/contracts/interfaces/IStakingVesting.sol";
import { IFastFinalityTracking } from "@ronin/contracts/interfaces/IFastFinalityTracking.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract REP10_BaseTest is Test, GlobalConfigConsumer {
  bytes param;
  address governanceAdmin;
  IProfile public profile;
  IStaking public staking;
  IStakingVesting public stakingVesting;
  ISlashIndicator public slashIndicator;
  IRandomBeacon public roninRandomBeacon;
  IRoninValidatorSet public roninValidatorSet;
  IFastFinalityTracking public fastFinalityTracking;
  IRoninTrustedOrganization public roninTrustedOrganization;

  function setUp() public virtual {
    DeployDPoS dposDeployHelper = new DeployDPoS();
    dposDeployHelper.setUp();
    param = vme.getRawSharedArguments();
    dposDeployHelper.run();
    LibPrecompile.deployPrecompile();

    governanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());
    profile = IProfile(loadContract(Contract.Profile.key()));
    staking = IStaking(loadContract(Contract.Staking.key()));
    stakingVesting = IStakingVesting(loadContract(Contract.StakingVesting.key()));
    slashIndicator = ISlashIndicator(loadContract(Contract.SlashIndicator.key()));
    roninValidatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    fastFinalityTracking = IFastFinalityTracking(loadContract(Contract.FastFinalityTracking.key()));
    roninRandomBeacon = IRandomBeacon(loadContract(Contract.RoninRandomBeacon.key()));
    roninTrustedOrganization = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    dposDeployHelper.cheatSetUpValidators();

    vm.warp(_bound(vm.getBlockTimestamp(), vm.unixTime() / 1_000, type(uint40).max));
    vme.rollUpTo(1000);

    LibWrapUpEpoch.wrapUpEpoch();
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

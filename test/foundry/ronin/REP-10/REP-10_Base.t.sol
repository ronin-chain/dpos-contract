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
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { GlobalConfigConsumer } from "@ronin/contracts/extensions/consumers/GlobalConfigConsumer.sol";
import { RoninRandomBeacon } from "@ronin/contracts/ronin/random-beacon/RoninRandomBeacon.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { LibArray } from "@ronin/contracts/libraries/LibArray.sol";
import { LibSortValidatorsByBeacon } from "@ronin/contracts/libraries/LibSortValidatorsByBeacon.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { ISlashRandomBeacon } from "@ronin/contracts/interfaces/slash-indicator/ISlashRandomBeacon.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { IBaseSlash } from "@ronin/contracts/interfaces/slash-indicator/IBaseSlash.sol";
import { RandomRequest } from "@ronin/contracts/libraries/LibSLA.sol";
import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { StakingVesting } from "@ronin/contracts/ronin/StakingVesting.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract REP10_BaseTest is Test, GlobalConfigConsumer {
  bytes param;
  address governanceAdmin;
  Profile public profile;
  Staking public staking;
  StakingVesting public stakingVesting;
  SlashIndicator public slashIndicator;
  RoninRandomBeacon public roninRandomBeacon;
  RoninValidatorSet public roninValidatorSet;
  FastFinalityTracking public fastFinalityTracking;
  RoninTrustedOrganization public roninTrustedOrganization;

  function setUp() public virtual {
    DeployDPoS dposDeployHelper = new DeployDPoS();
    param = vme.getRawSharedArguments();
    dposDeployHelper.run();
    LibPrecompile.deployPrecompile();

    governanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());
    profile = Profile(loadContract(Contract.Profile.key()));
    staking = Staking(loadContract(Contract.Staking.key()));
    stakingVesting = StakingVesting(loadContract(Contract.StakingVesting.key()));
    slashIndicator = SlashIndicator(loadContract(Contract.SlashIndicator.key()));
    roninValidatorSet = RoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    fastFinalityTracking = FastFinalityTracking(loadContract(Contract.FastFinalityTracking.key()));
    roninRandomBeacon = RoninRandomBeacon(loadContract(Contract.RoninRandomBeacon.key()));
    roninTrustedOrganization = RoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

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

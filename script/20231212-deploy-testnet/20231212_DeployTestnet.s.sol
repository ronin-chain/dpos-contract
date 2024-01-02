// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { console2 as console } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import "./contracts/ProfileDeploy.s.sol";
import "./contracts/StakingDeploy.s.sol";
import "./contracts/MaintenanceDeploy.s.sol";
import "./contracts/SlashIndicatorDeploy.s.sol";
import "./contracts/StakingVestingDeploy.s.sol";
import "./contracts/RoninValidatorSetDeploy.s.sol";
import "./contracts/FastFinalityTrackingDeploy.s.sol";
import "./contracts/RoninGovernanceAdminDeploy.s.sol";
import "./contracts/RoninTrustedOrganizationDeploy.s.sol";
import "./TestnetMigration.s.sol";
import { DefaultContract } from "foundry-deployment-kit/utils/DefaultContract.sol";

contract Migration__20231212_DeployTestnet is TestnetMigration {
  using LibProxy for *;
  using StdStyle for *;

  Profile profile;
  Staking staking;
  Maintenance maintenance;
  SlashIndicator slashIndicator;
  StakingVesting stakingVesting;
  RoninValidatorSet validatorSet;
  RoninTrustedOrganization trustedOrg;
  RoninGovernanceAdmin governanceAdmin;
  FastFinalityTracking fastFinalityTracking;

  function run() public onlyOn(DefaultNetwork.RoninTestnet.key()) {
    console.log("current block number:", block.number);

    ISharedArgument.SharedParameter memory param = testnetConfig.sharedArguments();
    address initialOwner = param.initialOwner;
    vm.label(initialOwner, "initialOwner");

    console.log("initialOwner", initialOwner);
    console.log("sender", sender());

    validatorSet = new RoninValidatorSetDeploy().run();
    trustedOrg = new RoninTrustedOrganizationDeploy().run();
    governanceAdmin = new RoninGovernanceAdminDeploy().run();

    console.log("trustedOrg admin", payable(address(trustedOrg)).getProxyAdmin());
    console.log("validatorSet admin", payable(address(validatorSet)).getProxyAdmin());

    profile = new ProfileDeploy().run();
    staking = new StakingDeploy().run();
    maintenance = new MaintenanceDeploy().run();
    slashIndicator = new SlashIndicatorDeploy().run();
    stakingVesting = new StakingVestingDeploy().run();
    fastFinalityTracking = new FastFinalityTrackingDeploy().run();

    // change ProxyAdmin to RoninGovernanceAdmin
    vm.startBroadcast(initialOwner);
    TransparentUpgradeableProxy(payable(address(trustedOrg))).changeAdmin(address(governanceAdmin));
    TransparentUpgradeableProxy(payable(address(validatorSet))).changeAdmin(address(governanceAdmin));
    vm.stopBroadcast();

    // assert all system contracts point to RoninGovernanceAdmin at ProxyAdmin slot
    assertEq(payable(address(staking)).getProxyAdmin(), address(governanceAdmin));
    assertEq(payable(address(trustedOrg)).getProxyAdmin(), address(governanceAdmin));
    assertEq(payable(address(maintenance)).getProxyAdmin(), address(governanceAdmin));
    assertEq(payable(address(validatorSet)).getProxyAdmin(), address(governanceAdmin));
    assertEq(payable(address(stakingVesting)).getProxyAdmin(), address(governanceAdmin));
    assertEq(payable(address(slashIndicator)).getProxyAdmin(), address(governanceAdmin));
    assertEq(payable(address(fastFinalityTracking)).getProxyAdmin(), address(governanceAdmin));

    // initialize neccessary config
    _initProfile();
    _initStaking(param);
    _initTrustedOrg(param);
    _initMaintenance(param);
    _initValidatorSet(param);
    _initSlashIndicator(param);
    _initStakingVesting(param);
    _initFastFinalityTracking();
  }

  function _initProfile() internal logFn("_initProfile") {
    vm.startBroadcast(sender());
    profile.initialize(address(validatorSet));
    vm.stopBroadcast();
  }

  function _initSlashIndicator(ISharedArgument.SharedParameter memory param) internal logFn("_initSlashIndicator") {
    uint256[4] memory bridgeOperatorSlashingConfig;
    uint256[2] memory bridgeVotingSlashingConfig;
    uint256[3] memory doubleSignSlashingConfig;
    uint256[4] memory unavailabilitySlashingConfig;
    uint256[4] memory creditScoreConfig;

    ISharedArgument.CreditScore memory creditScore = param.creditScore;
    ISharedArgument.DoubleSignSlashing memory doubleSignSlashing = param.doubleSignSlashing;
    ISharedArgument.BridgeVotingSlashing memory bridgeVotingSlashing = param.bridgeVotingSlashing;
    ISharedArgument.UnavailabilitySlashing memory unavailabilitySlashing = param.unavailabilitySlashing;
    ISharedArgument.BridgeOperatorSlashing memory bridgeOperatorSlashing = param.bridgeOperatorSlashing;

    assembly {
      bridgeOperatorSlashingConfig := bridgeOperatorSlashing
      bridgeVotingSlashingConfig := bridgeVotingSlashing
      doubleSignSlashingConfig := doubleSignSlashing
      unavailabilitySlashingConfig := unavailabilitySlashing
      creditScoreConfig := creditScore
    }

    vm.startBroadcast(sender());
    slashIndicator.initialize(
      address(validatorSet),
      address(maintenance),
      address(trustedOrg),
      address(governanceAdmin),
      bridgeOperatorSlashingConfig,
      bridgeVotingSlashingConfig,
      doubleSignSlashingConfig,
      unavailabilitySlashingConfig,
      creditScoreConfig
    );
    slashIndicator.initializeV3(address(profile));
    vm.stopBroadcast();
  }

  function _initTrustedOrg(ISharedArgument.SharedParameter memory param) internal logFn("_initTrustedOrg") {
    vm.startBroadcast(sender());
    trustedOrg.initialize(param.trustedOrganizations, param.numerator, param.denominator);
    vm.stopBroadcast();
  }

  function _initValidatorSet(ISharedArgument.SharedParameter memory param) internal logFn("_initValidatorSet") {
    uint256[2] memory emergencyConfig;
    emergencyConfig[0] = param.emergencyExitLockedAmount;
    emergencyConfig[1] = param.emergencyExpiryDuration;

    vm.startBroadcast(sender());
    validatorSet.initialize(
      address(slashIndicator),
      address(staking),
      address(stakingVesting),
      address(maintenance),
      address(trustedOrg),
      address(0x0),
      param.maxValidatorNumber,
      param.maxValidatorCandidate,
      param.maxPrioritizedValidatorNumber,
      param.minEffectiveDaysOnwards,
      param.numberOfBlocksInEpoch,
      emergencyConfig
    );
    // validatorSet.initializeV2();
    validatorSet.initializeV3(address(fastFinalityTracking));
    vm.stopBroadcast();
  }

  function _initStaking(ISharedArgument.SharedParameter memory param) internal logFn("_initStaking") {
    vm.startBroadcast(sender());
    staking.initialize(
      address(validatorSet),
      param.minValidatorStakingAmount,
      param.maxCommissionRate,
      param.cooldownSecsToUndelegate,
      param.waitingSecsToRevoke
    );
    vm.stopBroadcast();
  }

  function _initStakingVesting(ISharedArgument.SharedParameter memory param) internal logFn("_initStakingVesting") {
    vm.startBroadcast(sender());
    stakingVesting.initialize(
      address(validatorSet), param.blockProducerBonusPerBlock, param.bridgeOperatorBonusPerBlock
    );
    stakingVesting.initializeV3(param.fastFinalityRewardPercent);
    vm.stopBroadcast();
  }

  function _initMaintenance(ISharedArgument.SharedParameter memory param) internal logFn("_initMaintenance") {
    vm.startBroadcast(sender());
    maintenance.initialize(
      address(validatorSet),
      param.minMaintenanceDurationInBlock,
      param.maxMaintenanceDurationInBlock,
      param.minOffsetToStartSchedule,
      param.maxOffsetToStartSchedule,
      param.maxSchedules,
      param.cooldownSecsToMaintain
    );
    vm.stopBroadcast();
  }

  function _initFastFinalityTracking() internal logFn("_initFastFinalityTracking") {
    vm.startBroadcast(sender());
    fastFinalityTracking.initialize(address(validatorSet));
    vm.stopBroadcast();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IMaintenance } from "@ronin/contracts/interfaces/IMaintenance.sol";
import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";
import { IStakingVesting } from "@ronin/contracts/interfaces/IStakingVesting.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { IFastFinalityTracking } from "@ronin/contracts/interfaces/IFastFinalityTracking.sol";
import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { ProfileDeploy } from "script/contracts/ProfileDeploy.s.sol";
import { StakingDeploy } from "script/contracts/StakingDeploy.s.sol";
import { MaintenanceDeploy } from "script/contracts/MaintenanceDeploy.s.sol";
import { SlashIndicatorDeploy } from "script/contracts/SlashIndicatorDeploy.s.sol";
import { StakingVestingDeploy } from "script/contracts/StakingVestingDeploy.s.sol";
import { RoninValidatorSetDeploy } from "script/contracts/RoninValidatorSetDeploy.s.sol";
import { FastFinalityTrackingDeploy } from "script/contracts/FastFinalityTrackingDeploy.s.sol";
import { RoninGovernanceAdminDeploy } from "script/contracts/RoninGovernanceAdminDeploy.s.sol";
import { RoninTrustedOrganizationDeploy } from "script/contracts/RoninTrustedOrganizationDeploy.s.sol";
import { RoninRandomBeaconDeploy } from "script/contracts/RoninRandomBeaconDeploy.s.sol";
import {
  RoninValidatorSetREP10Migrator,
  RoninValidatorSetREP10MigratorLogicDeploy
} from "script/contracts/RoninValidatorSetRep10MigratorLogicDeploy.s.sol";
import "script/RoninMigration.s.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

contract DeployDPoS is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  // @dev Array to store proxy targets to change admin
  address[] internal _changeProxyTargets;

  uint256 internal _MAX_CANDIDATE = 7;
  address internal constant PAY_MASTER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

  IProfile profile;
  IStaking staking;
  IMaintenance maintenance;
  ISlashIndicator slashIndicator;
  IStakingVesting stakingVesting;
  IRoninValidatorSet validatorSet;
  IRandomBeacon randomBeacon;
  IRoninTrustedOrganization trustedOrg;
  IRoninGovernanceAdmin governanceAdmin;
  IFastFinalityTracking fastFinalityTracking;

  function run() public onlyOn(DefaultNetwork.Local.key()) {
    ISharedArgument.SharedParameter memory param = config.sharedArguments();
    address initialOwner = param.initialOwner;
    vm.label(initialOwner, "initialOwner");

    validatorSet = new RoninValidatorSetDeploy().run();
    trustedOrg = new RoninTrustedOrganizationDeploy().run();
    governanceAdmin = new RoninGovernanceAdminDeploy().run();

    profile = new ProfileDeploy().run();
    staking = new StakingDeploy().run();
    maintenance = new MaintenanceDeploy().run();
    slashIndicator = new SlashIndicatorDeploy().run();
    stakingVesting = new StakingVestingDeploy().run();
    fastFinalityTracking = new FastFinalityTrackingDeploy().run();
    randomBeacon = new RoninRandomBeaconDeploy().run();

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
    _initStaking(param.staking);
    _initTrustedOrg(param.roninTrustedOrganization);
    _initValidatorSet(param.roninValidatorSet);
    _initProfile();
    _initMaintenance(param.maintenance);
    _initSlashIndicator(param.slashIndicator);
    _initStakingVesting(param.stakingVesting);
    _initFastFinalityTracking();
    _initRoninRandomBeacon(param.roninRandomBeacon);
  }

  function setMaxCandidate(uint256 max) external {
    _MAX_CANDIDATE = max;
  }

  function _postCheck() internal virtual override {
    LibPrecompile.deployPrecompile();

    _cheatApplyGoverningValidatorCandidates();
    _cheatAddVRFKeysForGoverningValidators();
    _cheatApplyValidatorCandidates();

    super._postCheck();
  }

  function cheatSetUpValidators() external {
    _cheatApplyGoverningValidatorCandidates();
    _cheatAddVRFKeysForGoverningValidators();
    _cheatApplyValidatorCandidates();
  }

  function _cheatApplyGoverningValidatorCandidates() internal {
    // apply validator candidates
    console.log(">", "Cheat Applying Governing Validator Candidates".yellow());

    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    uint256 minValidatorStakingAmount = staking.minValidatorStakingAmount();
    (uint256 min, uint256 max) = staking.getCommissionRateRange();
    // uint256 commissionRate = min + (max - min) / 2;
    uint256 commissionRate = 100_00;

    uint[2] memory stakes = [
      uint256(6904000 ether),
      uint256(9014000 ether)];

    for (uint256 i; i < allTrustedOrgs.length; ++i) {
      (address candidateAdmin, uint256 privateKey) = makeAddrAndKey(string.concat("gv-candidate-", vm.toString(i)));
      bytes memory pubKey = bytes(string.concat("gv-pubKey-", vm.toString(allTrustedOrgs[i].governor)));
      uint256 stakeAmount = stakes[i];
      //   _bound(uint256(keccak256(abi.encode(vm.unixTime()))), minValidatorStakingAmount, type(uint96).max);


      // cheat to pass post check
      if (i == 0) stakeAmount = minValidatorStakingAmount + 1;

      vm.deal(PAY_MASTER, stakeAmount);
      prankOrBroadcast(PAY_MASTER);
      payable(candidateAdmin).transfer(stakeAmount);

      prankOrBroadcast(candidateAdmin);
      staking.applyValidatorCandidate{ value: stakeAmount }(
        candidateAdmin, allTrustedOrgs[i].consensusAddr, payable(candidateAdmin), commissionRate, pubKey, ""
      );

      console.log(
        string.concat(
          "Governing Candidate Admin:",
          " ",
          vm.toString(i),
          " ",
          vm.toString(candidateAdmin),
          " ",
          "Private key:",
          " ",
          vm.toString(privateKey)
        )
      );
    }
  }

  function _cheatAddVRFKeysForGoverningValidators() internal {
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    LibVRFProof.VRFKey[] memory vrfKeys = LibVRFProof.genVRFKeys(allTrustedOrgs.length);
    config.setUserDefinedConfig("vrf-keys", abi.encode(vrfKeys));

    for (uint256 i; i < vrfKeys.length; ++i) {
      address cid = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
      address admin = profile.getId2Admin(cid);
      vm.broadcast(admin);
      profile.changeVRFKeyHash(cid, vrfKeys[i].keyHash);
    }
  }

  function _initRoninRandomBeacon(ISharedArgument.RoninRandomBeaconParam memory param)
    internal
    logFn("_initRoninRandomBeacon")
  {
    vm.startBroadcast(sender());
    vm.recordLogs();
    randomBeacon.initialize({
      profile: address(profile),
      staking: address(staking),
      trustedOrg: address(trustedOrg),
      validatorSet: address(validatorSet),
      slashThreshold: param.slashThreshold,
      activatedAtPeriod: param.activatedAtPeriod,
      validatorTypes: param.validatorTypes,
      thresholds: param.thresholds
    });
    vm.stopBroadcast();
  }

  function _cheatApplyValidatorCandidates() internal {
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    uint256 maxValidatorCandidate = _MAX_CANDIDATE - allTrustedOrgs.length;

    uint256 minValidatorStakingAmount = staking.minValidatorStakingAmount();
    (uint256 min, uint256 max) = staking.getCommissionRateRange();
    // uint256 commissionRate = min + (max - min) / 2;
    uint256 commissionRate = 100_00;

    uint256[5] memory stakes = [
      uint256(7210_000 ether),
      uint256(5611_000 ether),
      uint256(7212_000 ether),
      uint256(6277_000 ether),
      uint256(6579_00_000 ether)
    ];

    for (uint256 i; i < maxValidatorCandidate; ++i) {
      bytes memory pubKey = bytes(string.concat("sv-pubKey-", vm.toString(i)));
      address candidateAdmin = makeAddr(string.concat("sv-candidate-admin-", vm.toString(i)));
      TConsensus consensus = TConsensus.wrap(makeAddr(string.concat("sv-candidate-", vm.toString(i))));

      uint256 stakeAmount = stakes[i];
        // _bound(uint256(keccak256(abi.encode(vm.unixTime()))), minValidatorStakingAmount, type(uint96).max);
      vm.deal(PAY_MASTER, stakeAmount);
      prankOrBroadcast(PAY_MASTER);
      payable(candidateAdmin).transfer(stakeAmount);

      prankOrBroadcast(candidateAdmin);
      staking.applyValidatorCandidate{ value: stakeAmount }(
        candidateAdmin, consensus, payable(candidateAdmin), commissionRate, pubKey, ""
      );
    }
  }

  function _initProfile() internal logFn("_initProfile") {
    vm.startBroadcast(sender());
    profile.initialize(address(validatorSet));
    profile.initializeV2(address(staking), address(trustedOrg));
    vm.stopBroadcast();
  }

  function _initSlashIndicator(ISharedArgument.SlashIndicatorParam memory param) internal logFn("_initSlashIndicator") {
    uint256[4] memory bridgeOperatorSlashingConfig;
    uint256[2] memory bridgeVotingSlashingConfig;
    uint256[3] memory doubleSignSlashingConfig;
    uint256[4] memory unavailabilitySlashingConfig;
    uint256[4] memory creditScoreConfig;

    ISharedArgument.CreditScoreParam memory creditScore = param.creditScore;
    ISharedArgument.SlashDoubleSignParam memory doubleSignSlashing = param.slashDoubleSign;
    ISharedArgument.SlashBridgeVotingParam memory bridgeVotingSlashing = param.__deprecatedSlashBridgeVoting;
    ISharedArgument.SlashUnavailabilityParam memory unavailabilitySlashing = param.slashUnavailability;
    ISharedArgument.SlashBridgeOperatorParam memory bridgeOperatorSlashing = param.__deprecatedSlashBridgeOperator;

    assembly ("memory-safe") {
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
    // slashIndicator.initializeV2(address(validatorSet));
    slashIndicator.initializeV3(address(profile));
    slashIndicator.initializeV4(
      address(randomBeacon), param.slashRandomBeacon.randomBeaconSlashAmount, param.slashRandomBeacon.activatedAtPeriod
    );

    vm.stopBroadcast();
  }

  function _initTrustedOrg(ISharedArgument.RoninTrustedOrganizationParam memory param)
    internal
    logFn("_initTrustedOrg")
  {
    vm.startBroadcast(sender());
    trustedOrg.initialize(param.trustedOrganizations, param.numerator, param.denominator);
    trustedOrg.initializeV2(address(profile));
    vm.stopBroadcast();
  }

  function _initValidatorSet(ISharedArgument.RoninValidatorSetParam memory param) internal logFn("_initValidatorSet") {
    address migrator = new RoninValidatorSetREP10MigratorLogicDeploy().run();

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
    validatorSet.initializeV4(address(profile));
    vm.stopBroadcast();

    UpgradeInfo({
      proxy: address(validatorSet),
      logic: migrator,
      callValue: 0,
      shouldPrompt: true,
      callData: abi.encodeCall(RoninValidatorSetREP10Migrator.initialize, (address(randomBeacon))),
      proxyInterface: ProxyInterface.Transparent,
      upgradeCallback: this.upgradeCallback,
      shouldUseCallback: true
    }).upgrade();
  }

  function _initStaking(ISharedArgument.StakingParam memory param) internal logFn("_initStaking") {
    vm.startBroadcast(sender());
    staking.initialize(
      address(validatorSet),
      param.minValidatorStakingAmount,
      param.maxCommissionRate,
      param.cooldownSecsToUndelegate,
      param.waitingSecsToRevoke
    );
    // staking.initializeV2();
    staking.initializeV3(address(profile));
    vm.stopBroadcast();
  }

  function _initStakingVesting(ISharedArgument.StakingVestingParam memory param) internal logFn("_initStakingVesting") {
    vm.startBroadcast(sender());
    stakingVesting.initialize(
      address(validatorSet), param.blockProducerBonusPerBlock, param.bridgeOperatorBonusPerBlock
    );
    // stakingVesting.initializeV2();
    stakingVesting.initializeV3(param.fastFinalityRewardPercent);
    vm.stopBroadcast();
  }

  function _initMaintenance(ISharedArgument.MaintenanceParam memory param) internal logFn("_initMaintenance") {
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
    // maintenance.initializeV2();
    maintenance.initializeV3(address(profile));
    vm.stopBroadcast();
  }

  function _initFastFinalityTracking() internal logFn("_initFastFinalityTracking") {
    vm.startBroadcast(sender());
    fastFinalityTracking.initialize(address(validatorSet));
    fastFinalityTracking.initializeV2(address(profile));
    fastFinalityTracking.initializeV3(address(staking));
    vm.stopBroadcast();
  }
}

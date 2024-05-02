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
import "./contracts/RoninRandomBeaconDeploy.s.sol";
import "./DPoSMigration.s.sol";

contract DeployDPoS is DPoSMigration {
  using LibProxy for *;
  using StdStyle for *;

  // @dev Array to store proxy targets to change admin
  address[] internal _changeProxyTargets;

  address payMaster;

  Profile profile;
  Staking staking;
  Maintenance maintenance;
  SlashIndicator slashIndicator;
  StakingVesting stakingVesting;
  RoninValidatorSet validatorSet;
  RoninRandomBeacon randomBeacon;
  RoninTrustedOrganization trustedOrg;
  RoninGovernanceAdmin governanceAdmin;
  FastFinalityTracking fastFinalityTracking;

  function run() public onlyOn(DefaultNetwork.Local.key()) {
    {
      address mockPrecompile = _deployLogic(Contract.MockPrecompile.key());
      vm.etch(address(0x68), mockPrecompile.code);
      vm.makePersistent(address(0x68));
      vm.etch(address(0x6a), mockPrecompile.code);
      vm.makePersistent(address(0x6a));
    }

    console.log("current block number:", block.number);

    ISharedArgument.SharedParameter memory param = cfg.sharedArguments();
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
    _initTrustedOrg(param.trustedOrganization);
    _initValidatorSet(param.roninValidatorSet);
    _initProfile();
    _initMaintenance(param.maintenance);
    _initSlashIndicator(param.slashIndicator);
    _initStakingVesting(param.stakingVesting);
    _initFastFinalityTracking();
    _initRoninRandomBeacon(param.roninRandomBeacon);

    _applyValidatorCandidates();
  }

  function _applyValidatorCandidates() internal {
    _fastForwardToNextDay();
    _wrapUpEpoch();

    uint256 maxValidatorCandidate = 70;

    // apply validator candidates
    console.log(">", StdStyle.green("Applying Validator Candidates"));

    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();

    uint256 minValidatorStakingAmount = staking.minValidatorStakingAmount();
    (uint256 min, uint256 max) = staking.getCommissionRateRange();
    uint256 commissionRate = min + (max - min) / 2;

    uint256 c;

    for (uint256 i; i < allTrustedOrgs.length; ++i) {
      bytes memory pubKey = bytes(string.concat("gv-pubKey-", vm.toString(allTrustedOrgs[i].governor)));
      address candidateAdmin = makeAddr(string.concat("gv-candidate-admin-", vm.toString(allTrustedOrgs[i].governor)));
      uint256 stakeAmount =
        _bound(uint256(keccak256(abi.encode(vm.unixTime()))), minValidatorStakingAmount, type(uint96).max);
      vm.deal(payMaster, stakeAmount);
      vm.broadcast(payMaster);
      payable(candidateAdmin).transfer(stakeAmount);

      vm.broadcast(candidateAdmin);
      staking.applyValidatorCandidate{ value: stakeAmount }(
        candidateAdmin, allTrustedOrgs[i].consensusAddr, payable(candidateAdmin), commissionRate, pubKey, ""
      );

      c++;
    }

    vm.deal(payMaster, minValidatorStakingAmount + 1);
    vm.broadcast(payMaster);
    payable(makeAddr("sv-candidate-admin-min")).transfer(minValidatorStakingAmount + 1);
    vm.broadcast(makeAddr("sv-candidate-admin-min"));
    staking.applyValidatorCandidate{ value: minValidatorStakingAmount + 1 }(
      makeAddr("sv-candidate-admin-min"),
      TConsensus.wrap(makeAddr("sv-candidate-min")),
      payable(makeAddr("sv-candidate-admin-min")),
      commissionRate,
      bytes("sv-pubKey-min"),
      ""
    );

    for (uint256 i = c; i < maxValidatorCandidate; ++i) {
      bytes memory pubKey = bytes(string.concat("sv-pubKey-", vm.toString(i)));
      address candidateAdmin = makeAddr(string.concat("sv-candidate-admin-", vm.toString(i)));
      TConsensus consensus = TConsensus.wrap(makeAddr(string.concat("sv-candidate-", vm.toString(i))));

      uint256 stakeAmount =
        _bound(uint256(keccak256(abi.encode(vm.unixTime()))), minValidatorStakingAmount, type(uint96).max);
      vm.deal(payMaster, stakeAmount);
      vm.broadcast(payMaster);
      payable(candidateAdmin).transfer(stakeAmount);

      vm.startBroadcast(candidateAdmin);
      staking.applyValidatorCandidate{ value: stakeAmount }(
        candidateAdmin, consensus, payable(candidateAdmin), commissionRate, pubKey, ""
      );
      vm.stopBroadcast();
    }

    console.log("Validator Count", validatorSet.getValidatorCandidates().length);

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function _postCheck() internal override {
    // post check
    _validateValidatorSet();
    _validateGovernanceAdmin();
    super._postCheck();
  }

  function _validateValidatorSet() internal logFn("Validate Validator Set") {
    _fastForwardToNextDay();
    _wrapUpEpoch();
    _fastForwardToNextDay();
    _wrapUpEpoch();

    console.log(">", StdStyle.green("Validate Validator {wrapUpEpoch} successful"));
  }

  function _validateGovernanceAdmin() internal logFn("Validate Governance Admin") {
    // Get all contracts deployed from the current network
    address payable[] memory addrs = config.getAllAddresses(network());

    // Identify proxy targets to change admin
    for (uint256 i; i < addrs.length; ++i) {
      if (addrs[i].getProxyAdmin(false) == address(governanceAdmin)) {
        console.log("Target Proxy to migrate admin", vm.getLabel(addrs[i]));
        _changeProxyTargets.push(addrs[i]);
      }
    }
    address[] memory targets = _changeProxyTargets;
    for (uint256 i; i < targets.length; ++i) {
      TContract contractType = config.getContractTypeFromCurrentNetwok(targets[i]);
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractType, EMPTY_ARGS);
    }

    console.log(">", StdStyle.green("Validate Governance Admin Upgrade Proposal successful"));
  }

  function _initProfile() internal logFn("_initProfile") {
    vm.startBroadcast(sender());
    profile.initialize(address(validatorSet));
    profile.initializeV2(address(staking), address(trustedOrg));
    vm.stopBroadcast();
  }

  function _initRoninRandomBeacon(ISharedArgument.RoninRandomBeaconParam memory param)
    internal
    logFn("_initRoninRandomBeacon")
  {
    vm.startBroadcast(sender());
    randomBeacon.initialize(
      address(profile),
      address(staking),
      address(trustedOrg),
      address(validatorSet),
      address(slashIndicator),
      param.slashThreshold,
      param.initialSeed,
      param.activatedAtPeriod,
      param.validatorTypes,
      param.thresholds
    );
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
    slashIndicator.initializeV4(address(randomBeacon), param.slashRandomBeacon.randomBeaconSlashAmount);
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
    validatorSet.initializeV5(address(randomBeacon));
    vm.stopBroadcast();
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
    vm.stopBroadcast();
  }
}

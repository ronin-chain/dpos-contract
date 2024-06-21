// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TContract, TNetwork } from "@fdk/types/Types.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { IPostCheck } from "./interfaces/IPostCheck.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { vme } from "@fdk/utils/Constants.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { LibDeploy, DeployInfo, ProxyInterface, UpgradeInfo } from "@fdk/libraries/LibDeploy.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";

contract RoninMigration is BaseMigration {
  using LibProxy for *;
  using LibString for bytes32;

  ISharedArgument internal constant config = ISharedArgument(address(vme));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return vm.getCode("out/GeneralConfig.sol/GeneralConfig.json");
  }

  function _postCheck() internal virtual override {
    address postChecker = _deployImmutable(Contract.PostChecker.key());
    vm.allowCheatcodes(postChecker);
    IPostCheck(postChecker).run();
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawCallData) {
    ISharedArgument.SharedParameter memory param;

    if (
      network() == DefaultNetwork.LocalHost.key() || network() == DefaultNetwork.RoninTestnet.key()
        || network() == Network.RoninDevnet.key() || network() == Network.ShadowForkMainnet.key()
    ) {
      param.initialOwner = makeAddr("initial-owner");
      _setStakingParam(param.staking);
      _setMaintenanceParam(param.maintenance);
      _setStakingVestingParam(param.stakingVesting);
      _setSlashIndicatorParam(param.slashIndicator);
      _setGovernanceAdminParam(param.roninGovernanceAdmin);
      _setRoninValidatorSetParam(param.roninValidatorSet);
      _setTrustedOrganizationParam(param.roninTrustedOrganization);
      _setRoninRandomBeaconParam(param.roninRandomBeacon);
      _setRoninValidatorSetREP10Migrator(param.roninValidatorSetREP10Migrator);
    } else if (network() == DefaultNetwork.RoninMainnet.key()) {
      console.log("RoninMigration: RoninMainnet Migration");
    } else {
      revert("RoninMigration: Other network unsupported");
    }

    rawCallData = abi.encode(param);
  }

  function _setRoninValidatorSetREP10Migrator(ISharedArgument.RoninValidatorSetREP10MigratorParam memory param)
    internal
  {
    param.activatedAtPeriod =
      vm.envOr("RONIN_VALIDATOR_SET_REP10_MIGRATOR_ACTIVATED_AT_PERIOD", (vm.unixTime() / 1_000) / 1 days);
    console.log("RONIN_VALIDATOR_SET_REP10_MIGRATOR_ACTIVATED_AT_PERIOD: ", param.activatedAtPeriod);
  }

  function _setRoninRandomBeaconParam(ISharedArgument.RoninRandomBeaconParam memory param) internal {
    param.slashThreshold = vm.envOr("RANDOM_BEACON_SLASH_THRESHOLD", uint256(3));
    param.activatedAtPeriod = vm.envOr("RANDOM_BEACON_ACTIVATED_AT_PERIOD", (vm.unixTime() / 1_000) / 1 days);
    console.log("RANDOM_BEACON_ACTIVATED_AT_PERIOD: ", param.activatedAtPeriod);

    param.validatorTypes = new IRandomBeacon.ValidatorType[](4);
    param.validatorTypes[0] = IRandomBeacon.ValidatorType.Governing;
    param.validatorTypes[1] = IRandomBeacon.ValidatorType.Standard;
    param.validatorTypes[2] = IRandomBeacon.ValidatorType.Rotating;
    param.validatorTypes[3] = IRandomBeacon.ValidatorType.All;
    param.thresholds = new uint256[](4);
    param.thresholds[0] = vm.envOr("GOVERNING_VALIDATOR_THRESHOLD", uint256(4));
    param.thresholds[1] = vm.envOr("STANDARD_VALIDATOR_THRESHOLD", uint256(0));
    param.thresholds[2] = vm.envOr("ROTATING_VALIDATOR_THRESHOLD", uint256(11));
    param.thresholds[3] = vm.envOr("ALL_VALIDATOR_THRESHOLD", uint256(15));
  }

  function _setMaintenanceParam(ISharedArgument.MaintenanceParam memory param) internal view {
    param.maxSchedules = vm.envOr("MAX_SCHEDULES", uint256(3));
    param.minOffsetToStartSchedule = vm.envOr("MIN_OFFSET_TO_START_SCHEDULE", uint256(200));
    param.cooldownSecsToMaintain = vm.envOr("COOLDOWN_SECS_TO_MAINTAIN", uint256(3 days));
    param.maxOffsetToStartSchedule = vm.envOr("MAX_OFFSET_TO_START_SCHEDULE", uint256(200 * 7));
    param.minMaintenanceDurationInBlock = vm.envOr("MIN_MAINTENANCE_DURATION_IN_BLOCK", uint256(100));
    param.maxMaintenanceDurationInBlock = vm.envOr("MAX_MAINTENANCE_DURATION_IN_BLOCK", uint256(1000));
  }

  function _setStakingParam(ISharedArgument.StakingParam memory param) internal view {
    param.maxCommissionRate = vm.envOr("MAX_COMMISSION_RATE", uint256(100_00));
    param.waitingSecsToRevoke = vm.envOr("WAITING_SECS_TO_REVOKE", uint256(7 days));
    param.minValidatorStakingAmount = vm.envOr("MIN_VALIDATOR_STAKING_AMOUNT", uint256(100 ether));
    param.cooldownSecsToUndelegate = vm.envOr("COOLDOWN_SECS_TO_UNDELEGATE", uint256(3 days));
  }

  function _setStakingVestingParam(ISharedArgument.StakingVestingParam memory param) internal {
    param.topupAmount = vm.envOr("TOPUP_AMOUNT", uint256(100_000_000_000));
    param.fastFinalityRewardPercent = vm.envOr("FAST_FINALITY_REWARD_PERCENT", uint256(1_00)); // 1%
    param.fastFinalityRewardPercentREP10 = vm.envOr("FAST_FINALITY_REWARD_PERCENT_REP10", uint256(8_500)); // 85%
    param.activatedAtPeriod =
      vm.envOr("FAST_FINALITY_REWARD_ACTIVATED_AT_PERIOD", uint256((vm.unixTime() / 1_000) / 1 days));
    param.blockProducerBonusPerBlock = vm.envOr("BLOCK_PRODUCER_BONUS_PER_BLOCK", uint256(1_000));
    param.bridgeOperatorBonusPerBlock = vm.envOr("BRIDGE_OPERATOR_BONUS_PER_BLOCK", uint256(1_100));
  }

  function _setSlashIndicatorParam(ISharedArgument.SlashIndicatorParam memory param) internal {
    // Deprecated slash bridge operator
    param.__deprecatedSlashBridgeOperator.missingVotesRatioTier1 = vm.envOr("MISSING_VOTES_RATIO_TIER1", uint256(10_00)); // 10%
    param.__deprecatedSlashBridgeOperator.missingVotesRatioTier2 = vm.envOr("MISSING_VOTES_RATIO_TIER2", uint256(20_00)); // 20%
    param.__deprecatedSlashBridgeOperator.skipBridgeOperatorSlashingThreshold =
      vm.envOr("SKIP_BRIDGE_OPERATOR_SLASHING_THRESHOLD", uint256(10));
    param.__deprecatedSlashBridgeOperator.jailDurationForMissingVotesRatioTier2 =
      vm.envOr("JAIL_DURATION_FOR_MISSING_VOTES_RATIO_TIER2", uint256(28800 * 2));

    // Deprecated slash bridge voting
    param.__deprecatedSlashBridgeVoting.bridgeVotingThreshold = vm.envOr("BRIDGE_VOTING_THRESHOLD", uint256(28800 * 3));
    param.__deprecatedSlashBridgeVoting.bridgeVotingSlashAmount =
      vm.envOr("BRIDGE_VOTING_SLASH_AMOUNT", uint256(10_000 ether));

    // Slash double sign
    param.slashDoubleSign.slashDoubleSignAmount = vm.envOr("SLASH_DOUBLE_SIGN_AMOUNT", uint256(10 ether));
    param.slashDoubleSign.doubleSigningOffsetLimitBlock = vm.envOr("DOUBLE_SIGNING_OFFSET_LIMIT_BLOCK", uint256(28800));
    param.slashDoubleSign.doubleSigningJailUntilBlock =
      vm.envOr("DOUBLE_SIGNING_JAIL_UNTIL_BLOCK", uint256(type(uint256).max));

    // Slash unavailability
    param.slashUnavailability.unavailabilityTier1Threshold = vm.envOr("UNAVAILABILITY_TIER1_THRESHOLD", uint256(5));
    param.slashUnavailability.unavailabilityTier2Threshold = vm.envOr("UNAVAILABILITY_TIER2_THRESHOLD", uint256(10));
    param.slashUnavailability.slashAmountForUnavailabilityTier2Threshold =
      vm.envOr("SLASH_AMOUNT_FOR_UNAVAILABILITY_TIER2_THRESHOLD", uint256(1 ether));
    param.slashUnavailability.jailDurationForUnavailabilityTier2Threshold =
      vm.envOr("JAIL_DURATION_FOR_UNAVAILABILITY_TIER2_THRESHOLD", uint256(28800 * 2));

    // Slash random beacon
    param.slashRandomBeacon.randomBeaconSlashAmount = vm.envOr("SLASH_RANDOM_BEACON_AMOUNT", uint256(10 ether));
    param.slashRandomBeacon.activatedAtPeriod =
      vm.envOr("SLASH_RANDOM_BEACON_ACTIVATED_AT_PERIOD", uint256((vm.unixTime() / 1_000) / 1 days + 3));
    console.log("SLASH_RANDOM_BEACON_ACTIVATED_AT_PERIOD: ", param.slashRandomBeacon.activatedAtPeriod);

    // Credit score
    param.creditScore.gainCreditScore = vm.envOr("GAIN_CREDIT_SCORE", uint256(100));
    param.creditScore.maxCreditScore = vm.envOr("MAX_CREDIT_SCORE", uint256(2400));
    param.creditScore.bailOutCostMultiplier = vm.envOr("BAIL_OUT_COST_MULTIPLIER", uint256(2));
    param.creditScore.cutOffPercentageAfterBailout = vm.envOr("CUT_OFF_PERCENTAGE_AFTER_BAILOUT", uint256(50_00)); // 50%
  }

  function _setTrustedOrganizationParam(ISharedArgument.RoninTrustedOrganizationParam memory param) internal {
    param.trustedOrganizations = new IRoninTrustedOrganization.TrustedOrganization[](4);
    uint256 governorPk;
    uint256 consensusPk;
    address consensus;

    for (uint256 i; i < param.trustedOrganizations.length; i++) {
      param.trustedOrganizations[i].weight = vm.envOr("TRUSTED_ORGANIZATION_WEIGHT", uint256(100));
      (param.trustedOrganizations[i].governor, governorPk) = makeAddrAndKey(string.concat("governor-", vm.toString(i)));
      (consensus, consensusPk) = makeAddrAndKey(string.concat("consensus-", vm.toString(i)));
      param.trustedOrganizations[i].consensusAddr = TConsensus.wrap(consensus);
    }

    param.numerator = vm.envOr("TRUSTED_ORGANIZATION_NUMERATOR", uint256(0));
    param.denominator = vm.envOr("TRUSTED_ORGANIZATION_DENOMINATOR", uint256(1));
  }

  function _setRoninValidatorSetParam(ISharedArgument.RoninValidatorSetParam memory param) internal view {
    param.maxValidatorNumber = vm.envOr("MAX_VALIDATOR_NUMBER", uint256(15));
    param.maxPrioritizedValidatorNumber = vm.envOr("MAX_PRIORITIZED_VALIDATOR_NUMBER", uint256(4));
    param.numberOfBlocksInEpoch = vm.envOr("NUMBER_OF_BLOCKS_IN_EPOCH", uint256(200));
    param.maxValidatorCandidate = vm.envOr("MAX_VALIDATOR_CANDIDATE", uint256(100));
    param.minEffectiveDaysOnwards = vm.envOr("MIN_EFFECTIVE_DAYS_ONWARDS", uint256(7));
    param.emergencyExitLockedAmount = vm.envOr("EMERGENCY_EXIT_LOCKED_AMOUNT", uint256(500));
    param.emergencyExpiryDuration = vm.envOr("EMERGENCY_EXPIRY_DURATION", uint256(14 days));
  }

  function _setGovernanceAdminParam(ISharedArgument.RoninGovernanceAdminParam memory param) internal view {
    param.proposalExpiryDuration = vm.envOr("PROPOSAL_EXPIRY_DURATION", uint256(14 days));
  }

  function _deployProxy(TContract contractType)
    internal
    virtual
    override
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);
    bytes memory callData = arguments();

    address proxyAdmin = _getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    deployed = LibDeploy.deployTransparentProxyV2({
      implInfo: DeployInfo({
        callValue: 0,
        by: sender(),
        contractName: contractName,
        absolutePath: vme.getContractAbsolutePath(contractType),
        artifactName: contractName,
        constructorArgs: ""
      }),
      callValue: 0,
      proxyAdmin: _getProxyAdmin(),
      callData: callData
    });

    // validate proxy admin
    address actualProxyAdmin = deployed.getProxyAdmin();
    assertEq(
      actualProxyAdmin,
      proxyAdmin,
      string.concat(
        "BaseMigration: Invalid proxy admin\n",
        "Actual: ",
        vm.toString(actualProxyAdmin),
        "\nExpected: ",
        vm.toString(proxyAdmin)
      )
    );

    vme.setAddress(network(), contractType, deployed);
  }

  function _upgradeProxy(
    TContract contractType,
    bytes memory args,
    bytes memory argsLogicConstructor
  )
    internal
    virtual
    override
    logFn(string.concat("_upgradeProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable proxy)
  {
    proxy = loadContract(contractType);
    address logic = _deployLogic(contractType, argsLogicConstructor);

    UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: args,
      proxyInterface: ProxyInterface.Transparent,
      shouldPrompt: false,
      upgradeCallback: this.upgradeCallback,
      shouldUseCallback: true
    }).upgrade();
  }

  function upgradeCallback(
    address proxy,
    address logic,
    uint256, /* callValue */
    bytes memory callData,
    ProxyInterface /* proxyInterface */
  ) public virtual override {
    address proxyAdmin = proxy.getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "RoninMigration: Invalid {proxyAdmin} or {proxy} is not a Proxy contract");
    address governanceAdmin = _getProxyAdminFromCurrentNetwork();
    TNetwork currentNetwork = network();

    if (proxyAdmin == governanceAdmin) {
      // in case proxyAdmin is GovernanceAdmin
      if (
        currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == DefaultNetwork.RoninMainnet.key()
          || currentNetwork == Network.RoninDevnet.key() || currentNetwork == DefaultNetwork.LocalHost.key()
          || currentNetwork == Network.ShadowForkMainnet.key()
      ) {
        // handle for ronin network
        console.log(StdStyle.yellow("Voting on RoninGovernanceAdmin for upgrading..."));

        IRoninGovernanceAdmin roninGovernanceAdmin = IRoninGovernanceAdmin(governanceAdmin);
        bytes[] memory callDatas = new bytes[](1);
        uint256[] memory values = new uint256[](1);
        address[] memory targets = new address[](1);

        targets[0] = proxy;
        callDatas[0] = callData.length == 0
          ? abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logic))
          : abi.encodeCall(TransparentUpgradeableProxy.upgradeToAndCall, (logic, callData));

        Proposal.ProposalDetail memory proposal = LibProposal.buildProposal({
          governanceAdmin: roninGovernanceAdmin,
          expiry: vm.getBlockTimestamp() + 1 hours,
          targets: targets,
          values: values,
          callDatas: callDatas
        });

        LibProposal.executeProposal(
          roninGovernanceAdmin,
          IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key())),
          proposal
        );

        assertEq(proxy.getProxyImplementation(), logic, "RoninMigration: Upgrade failed");
      } else if (currentNetwork == Network.Goerli.key() || currentNetwork == Network.EthMainnet.key()) {
        // handle for ethereum
        revert("RoninMigration: Unhandled case for ETH");
      } else {
        revert("RoninMigration: Unhandled case");
      }
    } else if (proxyAdmin.code.length == 0) {
      // in case proxyAdmin is an eoa
      console.log(StdStyle.yellow("Upgrading with EOA wallet..."));
      vm.broadcast(address(proxyAdmin));
      if (callData.length == 0) TransparentUpgradeableProxy(payable(proxy)).upgradeTo(logic);
      else TransparentUpgradeableProxy(payable(proxy)).upgradeToAndCall(logic, callData);
    } else {
      console.log(StdStyle.yellow("Upgrading with owner of ProxyAdmin contract..."));
      // in case proxyAdmin is a ProxyAdmin contract
      ProxyAdmin proxyAdminContract = ProxyAdmin(proxyAdmin);
      address authorizedWallet = proxyAdminContract.owner();
      vm.broadcast(authorizedWallet);
      if (callData.length == 0) proxyAdminContract.upgrade(TransparentUpgradeableProxy(payable(proxy)), logic);
      else proxyAdminContract.upgradeAndCall(TransparentUpgradeableProxy(payable(proxy)), logic, callData);
    }
  }

  function _getProxyAdmin() internal view virtual override returns (address payable) {
    return payable(_getProxyAdminFromCurrentNetwork());
  }

  function _getProxyAdminFromCurrentNetwork() internal view virtual returns (address proxyAdmin) {
    if (network() == DefaultNetwork.LocalHost.key()) {
      address deployedProxyAdmin;
      try config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()) returns (address payable res) {
        deployedProxyAdmin = res;
      } catch { }

      return deployedProxyAdmin == address(0x0) ? sender() : deployedProxyAdmin;
    }

    return loadContract(Contract.RoninGovernanceAdmin.key());
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";

import { IStaking } from "@ronin/contracts/interfaces/staking/IStaking.sol";
import { RoninValidatorSetREP10Migrator } from
  "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetREP10Migrator.sol";
import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { ISlashIndicator } from "@ronin/contracts/interfaces/slash-indicator/ISlashIndicator.sol";

import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";
import { IFastFinalityTracking } from "@ronin/contracts/interfaces/IFastFinalityTracking.sol";

import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { IBaseStaking } from "@ronin/contracts/interfaces/staking/IBaseStaking.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";
import { ICandidateManager } from "@ronin/contracts/interfaces/validator/ICandidateManager.sol";
import { ISlashUnavailability } from "@ronin/contracts/interfaces/slash-indicator/ISlashUnavailability.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { ContractType } from "@ronin/contracts/utils/ContractType.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";

import { RoninMigration } from "script/RoninMigration.s.sol";
import { RoninRandomBeaconDeploy } from "script/contracts/RoninRandomBeaconDeploy.s.sol";
import { RoninValidatorSetREP10MigratorLogicDeploy } from
  "script/contracts/RoninValidatorSetREP10MigratorLogicDeploy.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TContract } from "@fdk/types/Types.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

abstract contract REP10_Config_Mainnet_Base is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  uint256 internal constant MAX_GV = 12; // Max Governing Validator Pick Threshold
  uint256 internal constant MAX_RV = 10; // Max Rotating Validator Pick Threshold
  uint256 internal constant MAX_SV = 0; // Max Standard Validator Pick Threshold

  uint256 internal constant RANDOM_BEACON_SLASH_THRESHOLD = 3; // Random Beacon Slash Threshold
  uint256 internal constant REP10_ACTIVATION_PERIOD = 19896; // Sun, 2024-June-22 00:00:00 UTC
  uint256 internal constant SLASH_RANDOM_BEACON_AMOUNT = 1_000 ether; // Random Beacon Slash Amount
  uint256 internal constant NEW_MAX_VALIDATOR_CANDIDATE = 64; // New Max Validator Candidate

  address internal constant BAKSON_WALLET = 0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059;

  address[] internal contractsToUpgrade;
  TContract[] internal contractTypesToUpgrade;

  address[] internal _targets;
  uint256[] internal _values;
  bytes[] internal _callDatas;

  address internal roninValidatorSetREP10LogicMigrator;

  IStaking internal staking;
  ISlashIndicator internal slashIndicator;
  IRandomBeacon internal roninRandomBeacon;
  IRoninValidatorSet internal roninValidatorSet;
  IRoninGovernanceAdmin internal roninGovernanceAdmin;
  IRoninTrustedOrganization internal roninTrustedOrganization;

  function run() public virtual onlyOn(DefaultNetwork.RoninMainnet.key()) {
    staking = IStaking(loadContract(Contract.Staking.key()));
    slashIndicator = ISlashIndicator(loadContract(Contract.SlashIndicator.key()));
    roninValidatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    roninGovernanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    roninTrustedOrganization = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));
  }

  function _postCheck() internal virtual override {
    // Validate Data Correctness
    uint256 rep10ActivationPeriod = roninRandomBeacon.getActivatedAtPeriod();
    (,, uint256 slashAmount,) = slashIndicator.getUnavailabilitySlashingConfigs();

    console.log("[Ronin Validator Set] Current Period".green(), roninValidatorSet.currentPeriod());

    console.log("[Slash Indicator] Unavailability Slash Amount:".yellow(), slashAmount / 1 ether, "RON");
    console.log(
      "[Slash Indicator] Ronin Random Beacon Slash Amount:".yellow(),
      slashIndicator.getRandomBeaconSlashingConfigs()._slashAmount / 1 ether,
      "RON"
    );
    console.log(
      "[Slash Indicator] Slash Random Beacon Activated At Period:".yellow(),
      slashIndicator.getRandomBeaconSlashingConfigs()._activatedAtPeriod
    );
    console.log(
      "[Ronin Random Beacon] REP-10 Ronin Random Beacon Activated At Period".yellow(),
      roninRandomBeacon.getActivatedAtPeriod()
    );
    console.log(
      "[Ronin Random Beacon] Slash Threshold:".yellow(), roninRandomBeacon.getUnavailabilitySlashThreshold(), "times"
    );
    console.log(
      "[Ronin Random Beacon] Max GV".yellow(),
      roninRandomBeacon.getValidatorThreshold(IRandomBeacon.ValidatorType.Governing)
    );
    console.log(
      "[Ronin Random Beacon] Max SV".yellow(),
      roninRandomBeacon.getValidatorThreshold(IRandomBeacon.ValidatorType.Standard)
    );
    console.log(
      "[Ronin Random Beacon] Max RV".yellow(),
      roninRandomBeacon.getValidatorThreshold(IRandomBeacon.ValidatorType.Rotating)
    );
    console.log("[Ronin Random Beacon] Cooldown Threshold".yellow(), roninRandomBeacon.COOLDOWN_PERIOD_THRESHOLD());
    console.log(
      "[Ronin Validator Set] REP-10 Activated At Period".yellow(),
      RoninValidatorSetREP10Migrator(payable(address(roninValidatorSetREP10LogicMigrator))).ACTIVATED_AT_PERIOD()
    );
    console.log("[Ronin Validator Set] Max Validator Candidate".yellow(), roninValidatorSet.maxValidatorCandidate());
    console.log("[Ronin Validator Set] Max Validator Number:".yellow(), roninValidatorSet.maxValidatorNumber());

    assertTrue(rep10ActivationPeriod > roninValidatorSet.currentPeriod(), "Invalid activated period for random beacon");
    assertEq(
      rep10ActivationPeriod,
      RoninValidatorSetREP10Migrator(payable(address(roninValidatorSetREP10LogicMigrator))).ACTIVATED_AT_PERIOD(),
      "[RoninValidatorSet] Invalid REP-10 activation period"
    );
    assertEq(roninValidatorSet.maxValidatorNumber(), 22, "[RoninValidatorSet] Invalid max validator number");
    assertEq(rep10ActivationPeriod, REP10_ACTIVATION_PERIOD, "[RoninRandomBeacon] Invalid activated period");

    assertEq(
      roninRandomBeacon.getUnavailabilitySlashThreshold(),
      RANDOM_BEACON_SLASH_THRESHOLD,
      "[RoninRandomBeacon] Invalid slash threshold"
    );
    assertEq(
      rep10ActivationPeriod,
      slashIndicator.getRandomBeaconSlashingConfigs()._activatedAtPeriod,
      "[SlashIndicator] Invalid activated period for random beacon"
    );
    assertEq(
      SLASH_RANDOM_BEACON_AMOUNT,
      slashIndicator.getRandomBeaconSlashingConfigs()._slashAmount,
      "[SlashIndicator] Invalid slash amount for random beacon"
    );
    assertEq(
      roninRandomBeacon.getActivatedAtPeriod(), REP10_ACTIVATION_PERIOD, "Invalid activated period for random beacon"
    );

    LibWrapUpEpoch.wrapUpEpoch();
    super._postCheck();
  }
}

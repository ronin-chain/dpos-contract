// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";

import { IStaking } from "src/interfaces/staking/IStaking.sol";
import { RoninValidatorSetREP10Migrator } from
  "src/ronin/validator/migrations/RoninValidatorSetREP10Migrator.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninValidatorSet } from "src/interfaces/validator/IRoninValidatorSet.sol";
import { ISlashIndicator } from "src/interfaces/slash-indicator/ISlashIndicator.sol";

import { IRandomBeacon } from "src/interfaces/random-beacon/IRandomBeacon.sol";
import { IFastFinalityTracking } from "src/interfaces/IFastFinalityTracking.sol";

import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { IBaseStaking } from "src/interfaces/staking/IBaseStaking.sol";
import { IRandomBeacon } from "src/interfaces/random-beacon/IRandomBeacon.sol";
import { ICandidateManager } from "src/interfaces/validator/ICandidateManager.sol";
import { ISlashUnavailability } from "src/interfaces/slash-indicator/ISlashUnavailability.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { Proposal } from "src/libraries/Proposal.sol";
import { ContractType } from "src/utils/ContractType.sol";
import { TConsensus } from "src/udvts/Types.sol";

import { RoninMigration } from "script/RoninMigration.s.sol";
import { RoninRandomBeaconDeploy } from "script/contracts/RoninRandomBeaconDeploy.s.sol";
import { RoninValidatorSetREP10MigratorLogicDeploy } from
  "script/contracts/RoninValidatorSetRep10MigratorLogicDeploy.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TContract } from "@fdk/types/Types.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

contract Migration__01_Upgrade_ShadowForkMainnet_Release_V0_8_0 is RoninMigration {
  using LibProxy for *;
  using StdStyle for *;

  uint256 private constant MAX_GV = 12;
  uint256 private constant MAX_RV = 10;
  uint256 private constant MAX_SV = 0;

  uint256 private constant RANDOM_BEACON_SLASH_THRESHOLD = 3;
  uint256 private constant REP10_ACTIVATION_PERIOD = 19879; // Wed, 2024-Jun-5 00:00:00 UTC
  uint256 private constant SLASH_RANDOM_BEACON_AMOUNT = 10_000 ether;
  uint256 private constant WAITING_SECS_TO_REVOKE = 1 days;

  address[] private contractsToUpgrade;
  TContract[] private contractTypesToUpgrade;

  address[] private _targets;
  uint256[] private _values;
  bytes[] private _callDatas;

  address private roninValidatorSetREP10LogicMigrator;

  IStaking private staking;
  ISlashIndicator private slashIndicator;
  IRoninValidatorSet private roninValidatorSet;
  IRandomBeacon private roninRandomBeacon;
  IRoninGovernanceAdmin private roninGovernanceAdmin;
  IRoninTrustedOrganization private roninTrustedOrganization;

  function run() public onlyOn(Network.ShadowForkMainnet.key()) {
    staking = IStaking(loadContract(Contract.Staking.key()));
    slashIndicator = ISlashIndicator(loadContract(Contract.SlashIndicator.key()));
    roninValidatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    roninGovernanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    roninTrustedOrganization = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    address payable[] memory allContracts = config.getAllAddresses(network());

    _deployRoninValidatorSetREP10MigratorLogic();
    _deployAndInitializeRoninRandomBeacon();

    _recordContractToUpgrade(address(roninGovernanceAdmin), allContracts); // Record contracts to upgrade

    (_targets, _values, _callDatas) = _buildProposalData();
    _updateProposalUpdateWaitingSecsToRevoke();

    Proposal.ProposalDetail memory proposal =
      LibProposal.buildProposal(roninGovernanceAdmin, vm.getBlockTimestamp() + 14 days, _targets, _values, _callDatas);
    LibProposal.executeProposal(roninGovernanceAdmin, roninTrustedOrganization, proposal);

    IRoninTrustedOrganization.TrustedOrganization[] memory trustedOrgs =
      roninTrustedOrganization.getAllTrustedOrganizations();

    for (uint256 i; i < trustedOrgs.length; i++) {
      console.log("[Trusted Organization]", "Governor:".yellow(), trustedOrgs[i].governor);
    }
  }

  function _postCheck() internal virtual override {
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
    console.log(
      "[Ronin Validator Set] REP-10 Activated At Period".yellow(),
      RoninValidatorSetREP10Migrator(payable(address(roninValidatorSetREP10LogicMigrator))).ACTIVATED_AT_PERIOD()
    );
    console.log("[Ronin Validator Set] Max Validator Candidate".yellow(), roninValidatorSet.maxValidatorCandidate());
    console.log("[Ronin Validator Set] Max Validator Number:".yellow(), roninValidatorSet.maxValidatorNumber());
    console.log(
      "[Staking] Waiting Secs To Revoke:".yellow(),
      IBaseStaking(loadContract(Contract.Staking.key())).waitingSecsToRevoke()
    );

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
    assertEq(staking.waitingSecsToRevoke(), WAITING_SECS_TO_REVOKE, "[Staking] Invalid waiting secs to revoke");

    LibWrapUpEpoch.wrapUpEpoch();
    super._postCheck();
  }

  function _updateProposalUpdateWaitingSecsToRevoke() internal {
    _targets.push(loadContract(Contract.Staking.key()));
    _callDatas.push(
      abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        (abi.encodeCall(IBaseStaking.setWaitingSecsToRevoke, (WAITING_SECS_TO_REVOKE)))
      )
    );
    _values.push(0);
  }

  function _deployRoninValidatorSetREP10MigratorLogic() internal {
    roninValidatorSetREP10LogicMigrator =
      new RoninValidatorSetREP10MigratorLogicDeploy().overrideActivatedAtPeriod(REP10_ACTIVATION_PERIOD).run();
  }

  function _deployAndInitializeRoninRandomBeacon() internal {
    roninRandomBeacon = new RoninRandomBeaconDeploy().run();

    IRandomBeacon.ValidatorType[] memory validatorTypes = new IRandomBeacon.ValidatorType[](4);
    uint256[] memory thresholds = new uint256[](4);

    validatorTypes[0] = IRandomBeacon.ValidatorType.Governing;
    validatorTypes[1] = IRandomBeacon.ValidatorType.Standard;
    validatorTypes[2] = IRandomBeacon.ValidatorType.Rotating;
    validatorTypes[3] = IRandomBeacon.ValidatorType.All;

    thresholds[0] = MAX_GV;
    thresholds[1] = MAX_SV;
    thresholds[2] = MAX_RV;
    thresholds[3] = MAX_GV + MAX_SV + MAX_RV;

    vm.startBroadcast(sender());

    roninRandomBeacon.initialize({
      profile: loadContract(Contract.Profile.key()),
      staking: loadContract(Contract.Staking.key()),
      trustedOrg: address(roninTrustedOrganization),
      validatorSet: loadContract(Contract.RoninValidatorSet.key()),
      slashThreshold: RANDOM_BEACON_SLASH_THRESHOLD,
      activatedAtPeriod: REP10_ACTIVATION_PERIOD,
      validatorTypes: validatorTypes,
      thresholds: thresholds
    });

    vm.stopBroadcast();
  }

  function _buildProposalData()
    internal
    returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas)
  {
    uint256 innerCallCount = contractTypesToUpgrade.length;
    console.log("Number contract to upgrade:", innerCallCount);

    callDatas = new bytes[](innerCallCount);
    targets = new address[](innerCallCount);
    values = new uint256[](innerCallCount);
    address[] memory logics = new address[](innerCallCount);

    for (uint256 i; i < innerCallCount; ++i) {
      targets[i] = contractsToUpgrade[i];

      if (contractTypesToUpgrade[i] != Contract.RoninValidatorSet.key()) {
        logics[i] = _deployLogic(contractTypesToUpgrade[i]);
        callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[i]));
      } else {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (
            roninValidatorSetREP10LogicMigrator,
            abi.encodeCall(RoninValidatorSetREP10Migrator.initialize, (address(roninRandomBeacon)))
          )
        );
      }

      if (contractTypesToUpgrade[i] == Contract.FastFinalityTracking.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (logics[i], abi.encodeCall(IFastFinalityTracking.initializeV3, (loadContract(Contract.Staking.key()))))
        );
      }

      if (contractTypesToUpgrade[i] == Contract.SlashIndicator.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (
            logics[i],
            abi.encodeCall(
              ISlashIndicator.initializeV4,
              (address(roninRandomBeacon), SLASH_RANDOM_BEACON_AMOUNT, REP10_ACTIVATION_PERIOD)
            )
          )
        );
      }
    }
  }

  function _recordContractToUpgrade(address gov, address payable[] memory allContracts) internal {
    for (uint256 i; i < allContracts.length; i++) {
      address proxyAdmin = allContracts[i].getProxyAdmin(false);
      if (proxyAdmin != gov) {
        console.log(
          unicode"⚠ WARNING:".yellow(),
          string.concat(
            vm.getLabel(allContracts[i]),
            " has different ProxyAdmin. Expected: ",
            vm.getLabel(gov),
            " Got: ",
            vm.toString(proxyAdmin)
          )
        );

        continue;
      }

      address implementation = allContracts[i].getProxyImplementation();
      TContract contractType = config.getContractTypeFromCurrentNetwork(allContracts[i]);

      if (implementation.codehash != keccak256(vm.getDeployedCode(config.getContractAbsolutePath(contractType)))) {
        console.log(
          "Different Code Hash Detected. Contract To Upgrade:".cyan(),
          vm.getLabel(allContracts[i]),
          string.concat(" Query code Hash From: ", vm.getLabel(implementation))
        );

        contractTypesToUpgrade.push(contractType);
        contractsToUpgrade.push(allContracts[i]);

        continue;
      }

      console.log("Contract not to Upgrade:", vm.getLabel(allContracts[i]));
    }
  }
}

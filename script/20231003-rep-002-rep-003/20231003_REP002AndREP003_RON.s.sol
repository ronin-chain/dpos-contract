// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20231003_REP002AndREP003_Base.s.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_RON is Simulation__20231003_UpgradeREP002AndREP003_Base {
  function run() public virtual override {
    super.run();

    _upgradeDPoSContracts();

    // test `RoninGatewayV3` functionality
    _depositForOnBothChain("before-upgrade-user");

    // trigger conditional migration
    LibWrapUpEpoch.wrapUpPeriod();

    // // test `RoninValidatorSet` functionality
    // LibWrapUpEpoch.fastForwardToNextDay();
    // LibWrapUpEpoch.wrapUpPeriod();

    // // test `RoninGatewayV3` functionality
    // _depositForOnBothChain("after-upgrade-user");
  }

  function _upgradeDPoSContracts() internal {
    {
      // upgrade `RoninValidatorSet` to `RoninValidatorSetTimedMigrator`
      // bump `RoninValidatorSet` to V2, V3
      new RoninValidatorSetTimedMigratorUpgrade().run();
    }

    {
      // upgrade `Staking` to `NotifiedMigrator`
      // bump `Staking` to V2
      bytes[] memory stakingCallDatas = new bytes[](1);
      stakingCallDatas[0] = abi.encodeCall(IStaking.initializeV2, ());
      IStaking(new NotifiedMigratorUpgrade().run(Contract.Staking, stakingCallDatas));
    }

    {
      // upgrade `SlashIndicator` to `NotifiedMigrator`
      // bump `SlashIndicator` to V2, V3
      bytes[] memory slashIndicatorDatas = new bytes[](2);
      slashIndicatorDatas[0] =
        abi.encodeCall(ISlashIndicator.initializeV2, (loadContract(Contract.RoninGovernanceAdmin.key())));
      slashIndicatorDatas[1] =
        abi.encodeCall(ISlashIndicator.initializeV3, (loadContractOrDeploy(Contract.Profile.key())));
      new NotifiedMigratorUpgrade().run(Contract.SlashIndicator, slashIndicatorDatas);
    }

    {
      // upgrade `RoninTrustedOrganization`
      bytes[] memory emptyCallDatas;
      new NotifiedMigratorUpgrade().run(Contract.RoninTrustedOrganization, emptyCallDatas);
    }

    {
      // upgrade `BridgeTracking` to `NotifiedMigrator`
      // bump `BridgeTracking` to V2
      bytes[] memory bridgeTrackingDatas = new bytes[](1);
      bridgeTrackingDatas[0] = abi.encodeCall(IBridgeTracking.initializeV2, ());
      _bridgeTracking = IBridgeTracking(new NotifiedMigratorUpgrade().run(Contract.BridgeTracking, bridgeTrackingDatas));
    }
  }
}

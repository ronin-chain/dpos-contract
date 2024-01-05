// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { ISharedArgument, IRoninTrustedOrganization } from "./interfaces/ISharedArgument.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";

contract TestnetMigration is RoninMigration {
  ISharedArgument internal constant testnetConfig = ISharedArgument(address(CONFIG));

  function _getProxyAdminFromCurrentNetwork() internal view virtual override returns (address proxyAdmin) {
    if (network() == DefaultNetwork.RoninTestnet.key()) {
      address deployedProxyAdmin;
      try testnetConfig.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()) returns (
        address payable res
      ) {
        if (res == 0x53Ea388CB72081A3a397114a43741e7987815896) deployedProxyAdmin = address(0x0);
        else deployedProxyAdmin = res;
      } catch {}

      proxyAdmin = deployedProxyAdmin == address(0x0)
        ? testnetConfig.sharedArguments().initialOwner
        : deployedProxyAdmin;
    }
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    // ToDo(TuDo1403):
    if (network() == DefaultNetwork.RoninTestnet.key()) {
      param.initialOwner = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;
      // maintenanceArguments
      param.minMaintenanceDurationInBlock = 100;
      param.maxMaintenanceDurationInBlock = 1000;
      param.minOffsetToStartSchedule = 200;
      param.maxOffsetToStartSchedule = 200 * 7;
      param.maxSchedules = 2;
      param.cooldownSecsToMaintain = 3 days;

      // stakingArguments
      param.minValidatorStakingAmount = 100;
      param.maxCommissionRate = 100_00;
      param.cooldownSecsToUndelegate = 3 days;
      param.waitingSecsToRevoke = 7 days;

      // stakingVestingArguments
      param.topupAmount = 100_000_000_000;
      param.fastFinalityRewardPercent = 1_00; // 1%
      param.blockProducerBonusPerBlock = 1_000;
      param.bridgeOperatorBonusPerBlock = 1_100;

      param.bridgeOperatorSlashing.missingVotesRatioTier1 = 10_00; // 10%
      param.bridgeOperatorSlashing.missingVotesRatioTier2 = 20_00; // 20%
      param.bridgeOperatorSlashing.jailDurationForMissingVotesRatioTier2 = 28800 * 2;
      param.bridgeOperatorSlashing.skipBridgeOperatorSlashingThreshold = 10;

      param.bridgeVotingSlashing.bridgeVotingThreshold = 28800 * 3;
      param.bridgeVotingSlashing.bridgeVotingSlashAmount = 10_000 ether;

      param.doubleSignSlashing.slashDoubleSignAmount = 10 ether;
      param.doubleSignSlashing.doubleSigningJailUntilBlock = type(uint256).max;
      param.doubleSignSlashing.doubleSigningOffsetLimitBlock = 28800;

      param.unavailabilitySlashing.unavailabilityTier1Threshold = 5;
      param.unavailabilitySlashing.unavailabilityTier2Threshold = 10;
      param.unavailabilitySlashing.slashAmountForUnavailabilityTier2Threshold = 1 ether;
      param.unavailabilitySlashing.jailDurationForUnavailabilityTier2Threshold = 28800 * 2;

      param.creditScore.gainCreditScore = 50;
      param.creditScore.maxCreditScore = 600;
      param.creditScore.bailOutCostMultiplier = 5;
      param.creditScore.cutOffPercentageAfterBailout = 50_00; // 50%

      param.trustedOrganizations = new IRoninTrustedOrganization.TrustedOrganization[](3);
      param.trustedOrganizations[0].weight = 100;
      param.trustedOrganizations[1].weight = 100;
      param.trustedOrganizations[2].weight = 100;

      param.trustedOrganizations[0].governor = 0x529502C69356E9f48C8D5427B030020941F9ef42;
      param.trustedOrganizations[0].consensusAddr = TConsensus.wrap(0x6D863059CF618cC03d314cfbC41707105DD3BB3d);
      // param.trustedOrganizations[0].bridgeVoter = 0xf098ec9886CCe889b36C92ccBc3c2b5fa64e09aE;

      param.trustedOrganizations[1].governor = 0x85C5dBfadcBc36AeE39DD32365183c5E38A67E37;
      param.trustedOrganizations[1].consensusAddr = TConsensus.wrap(0x412cA41498e0522f054ebBA32fCaf59C9e55F099);
      // param.trustedOrganizations[1].bridgeVoter = 0x8C505D4a1B56DA76E77AE0510C25f78F57394671;

      param.trustedOrganizations[2].governor = 0x947AB99ad90302b5ec1840c9b5CF4205554C72af;
      param.trustedOrganizations[2].consensusAddr = TConsensus.wrap(0x7CcE47da0E161BE6fA1c7D09A9d12986b03621A3);
      // param.trustedOrganizations[2].bridgeVoter = 0x336e8b062b1d3ce2D9A775929587c70Dc5E2Fa0B;

      param.numerator = 0;
      param.denominator = 1;

      // roninValidatorSetArguments
      param.maxValidatorNumber = 4;
      param.maxPrioritizedValidatorNumber = 0;
      param.numberOfBlocksInEpoch = 200;
      param.maxValidatorCandidate = 10;
      param.minEffectiveDaysOnwards = 7;
      param.emergencyExitLockedAmount = 500;
      param.emergencyExpiryDuration = 14 days; // 14 days

      param.proposalExpiryDuration = 14 days;
    } else {
      revert("TestnetMigration: Other network unsupported");
    }

    rawArgs = abi.encode(param);
  }
}

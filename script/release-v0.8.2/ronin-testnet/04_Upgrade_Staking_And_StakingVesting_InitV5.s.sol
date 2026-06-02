// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninMigration } from "script/RoninMigration.s.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { Staking } from "src/ronin/staking/Staking.sol";

import { LibProposal, Proposal } from "script/shared/libraries/LibProposal.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { ContractType } from "src/utils/ContractType.sol";

contract Migration_04_Upgrade_Staking_And_StakingVesting_InitV5_Release is RoninMigration {
  Proposal.ProposalDetail internal _proposal;
  IRoninGovernanceAdmin internal _governanceAdmin;
  IRoninTrustedOrganization internal _trustedOrg;

  function run() public {
    address migrator = sender();
    // address newStaking = _deployLogic(Contract.Staking.key());
    // address newStakingVesting = _deployLogic(Contract.StakingVesting.key());
    // address newRoninValidatorSet = _deployLogic(Contract.RoninValidatorSet.key());

    address[] memory targets = new address[](1);
    targets[0] = loadContract(Contract.Staking.key());
    // targets[1] = loadContract(Contract.StakingVesting.key());
    // targets[0] = loadContract(Contract.RoninValidatorSet.key());

    bytes[] memory callDatas = new bytes[](1);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxyV2.functionDelegateCall,
      abi.encodeWithSignature("setWaitingSecsToRevoke(uint256)", 5 minutes)
    );
    // callDatas[0] = abi.encodeWithSignature(
    //   "setContract(uint8,address)", uint8(ContractType.VALIDATOR), loadContract(Contract.RoninValidatorSet.key())
    // );
    // callDatas[1] = abi.encodeWithSignature(
    //   "upgradeToAndCall(address,bytes)",
    //   newStakingVesting,
    //   abi.encodeWithSignature(
    //     "initializeV5(address,address)", address(migrator), address(loadContract(Contract.Staking.key()))
    //   )
    // );
    // callDatas[0] = abi.encodeWithSignature("upgradeTo(address)", newRoninValidatorSet);

    uint256[] memory values = new uint256[](1);

    _governanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    _trustedOrg = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    _proposal =
      LibProposal.buildProposal(_governanceAdmin, vm.getBlockTimestamp() + 1 hours, targets, values, callDatas);
    LibProposal.executeProposal(_governanceAdmin, _trustedOrg, _proposal);
  }

  function _afterRunningScript() internal virtual override { }
}

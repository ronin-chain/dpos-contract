// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from
  "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";

import { IProfile } from "src/interfaces/IProfile.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";

import { Proposal } from "src/libraries/Proposal.sol";
import { RoninValidatorSetConstructor } from "src/ronin/validator/RoninValidatorSetConstructor.sol";

import { RoninMigration } from "script/RoninMigration.s.sol";

import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";

import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

contract Migration_01_Upgrade_TestnetShadow_Release_v0_8_2 is RoninMigration {
  uint256 internal constant DEFAULT_EXPIRY = 1 hours;

  function run() public virtual onlyOn(Network.RoninTestnetShadow.key()) {
    address zkFeePlaza = 0x3aB093b72EbD8B3B5222641b300Bd09EcBC6A6a6;
    address zkRollupManager = 0x3F087034ca3bA5792591cbB93CB1CCFb650Abf85;

    // Set the chain ID to the Ronin Testnet chain ID
    vm.chainId(vme.getNetworkData(DefaultNetwork.RoninTestnet.key()).chainId);

    address profileLogic = _deployLogic(Contract.Profile.key());
    address validatorSetInitializer = vm.deployCode("RoninValidatorSetConstructor.sol");
    address validatorSetLogic = _deployLogic(Contract.RoninValidatorSet.key());

    address[] memory targets = new address[](3);
    targets[0] = loadContract(Contract.Profile.key());
    targets[1] = loadContract(Contract.RoninValidatorSet.key());
    targets[2] = targets[1];

    uint256[] memory values = new uint256[](3);
    values[0] = 0;
    values[1] = 0;
    values[2] = 0;

    bytes[] memory callDatas = new bytes[](3);
    callDatas[0] = abi.encodeCall(
      TransparentUpgradeableProxy.upgradeToAndCall,
      (profileLogic, abi.encodeCall(IProfile.initializeV4, (zkRollupManager)))
    );
    callDatas[1] = abi.encodeCall(
      TransparentUpgradeableProxy.upgradeToAndCall,
      (validatorSetInitializer, abi.encodeCall(RoninValidatorSetConstructor.initializeV5, (zkFeePlaza)))
    );
    callDatas[2] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (validatorSetLogic));

    address gov = loadContract(Contract.RoninGovernanceAdmin.key());
    address trustedOrg = loadContract(Contract.RoninTrustedOrganization.key());

    Proposal.ProposalDetail memory proposal = LibProposal.buildProposal(
      IRoninGovernanceAdmin(gov), block.timestamp + DEFAULT_EXPIRY, targets, values, callDatas
    );

    LibProposal.executeProposal(IRoninGovernanceAdmin(gov), IRoninTrustedOrganization(trustedOrg), proposal);
  }

  function _afterRunningScript() internal virtual override {
    // Do nothing
  }
}

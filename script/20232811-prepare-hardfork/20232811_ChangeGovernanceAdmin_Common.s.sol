// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { console2 as console } from "forge-std/console2.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { Proposal, RoninMigration } from "script/RoninMigration.s.sol";
import { LibString, Contract } from "script/utils/Contract.sol";
import { RoninGovernanceAdmin, HardForkRoninGovernanceAdminDeploy } from "script/contracts/HardForkRoninGovernanceAdminDeploy.s.sol";
import { RoninTrustedOrganization, TemporalRoninTrustedOrganizationDeploy } from "script/contracts/TemporalRoninTrustedOrganizationDeploy.s.sol";
import { Profile_Testnet } from "@ronin/contracts/ronin/profile/Profile_Testnet.sol";

abstract contract Migration__20232811_ChangeGovernanceAdmin_Common is RoninMigration {
  using LibString for *;
  using LibErrorHandler for bool;
  using stdStorage for StdStorage;
  using LibProxy for address payable;

  address internal __roninGovernanceAdmin;
  RoninGovernanceAdmin internal __hardForkGovernanceAdmin;
  address internal __trustedOrg;

  function __node_hardfork_hook() internal virtual;

  function run() public {
    // ================================================= Simulation Scenario for HardFork Upgrade Scenario ==========================================

    // Denotation:
    // - Current Broken Ronin Governance Admin (X)
    // - Current Ronin Trusted Organization (Y)
    // - New Temporal Ronin Trusted Organization (A)
    // - New Ronin Governance Admin (B)

    // 1. Deploy new (A) which has extra interfaces ("sumGovernorWeights(address[])", "totalWeights()").
    // 2. Deploy (B) which is compatible with (Y).
    // 3. Cheat storage slot of Ronin Trusted Organization of current broken Ronin Governance Admin (Y) to point from (Y) -> (A)
    // 4. Create and Execute Proposal of changing all system contracts that have ProxAdmin address of (X) to change from (X) -> (A)
    // 5. Validate (A) functionalities

    // =========================================== NODE HARDFORK PARTS (1, 2, 3) ===============================================
    __node_hardfork_hook();

    // =========================================== CONTRACT PARTS (4, 5) ===============================================

    // Get all contracts deployed from the current network
    address payable[] memory addrs = config.getAllAddresses(network());

    // Identify proxy targets to change admin
    for (uint256 i; i < addrs.length; ++i) {
      try this.getProxyAdmin(addrs[i]) returns (address payable proxy) {
        if (proxy == __roninGovernanceAdmin) {
          console.log("Target Proxy to change admin with proposal", vm.getLabel(addrs[i]));
          _proxyTargets.push(addrs[i]);
        }
      } catch {}
    }

    {
      address[] memory targets = _proxyTargets;
      uint256[] memory values = new uint256[](targets.length);
      bytes[] memory callDatas = new bytes[](targets.length);

      // Build `changeAdmin` calldata to migrate to new Ronin Governance Admin
      for (uint256 i; i < targets.length; ++i) {
        callDatas[i] = abi.encodeWithSelector(
          TransparentUpgradeableProxy.changeAdmin.selector,
          address(__hardForkGovernanceAdmin)
        );
      }

      Proposal.ProposalDetail memory proposal = _buildProposal(
        RoninGovernanceAdmin(__roninGovernanceAdmin),
        block.timestamp + 5 minutes,
        targets,
        values,
        callDatas
      );

      // Execute the proposal
      _executeProposal(RoninGovernanceAdmin(__roninGovernanceAdmin), RoninTrustedOrganization(__trustedOrg), proposal);
    }

    // Change broken Ronin Governance Admin to new Ronin Governance Admin
    config.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(__hardForkGovernanceAdmin));

    // Migrate Profile contract for REP-4
    if (block.chainid == DefaultNetwork.RoninTestnet.chainId()) {
      // Cheat add Profile for community-validator: 0x9687e8C41fa369aD08FD278a43114C4207856a61,  0x32F66d0F9F19Db7b0EF1E9f13160884DA65467e7

      address profileProxy = config.getAddressFromCurrentNetwork(Contract.Profile.key());
      address newProfileLogic = _deployLogic(Contract.Profile_Testnet.key());

      address[] memory targets = new address[](2);
      targets[0] = profileProxy;
      targets[1] = profileProxy;
      uint256[] memory values = new uint256[](targets.length);
      bytes[] memory callDatas = new bytes[](targets.length);

      callDatas[0] = abi.encodeWithSelector(TransparentUpgradeableProxy.upgradeTo.selector, newProfileLogic);
      callDatas[1] = abi.encodeWithSelector(
        TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        // address(__hardForkGovernanceAdmin)
        abi.encodeWithSelector(Profile_Testnet.migrateRenouncedCandidate.selector)
      );

      Proposal.ProposalDetail memory proposal = _buildProposal(
        RoninGovernanceAdmin(__hardForkGovernanceAdmin),
        block.timestamp + 5 minutes,
        targets,
        values,
        callDatas
      );

      // Execute the proposal
      _executeProposal(
        RoninGovernanceAdmin(__hardForkGovernanceAdmin),
        RoninTrustedOrganization(__trustedOrg),
        proposal
      );
    }
  }
}

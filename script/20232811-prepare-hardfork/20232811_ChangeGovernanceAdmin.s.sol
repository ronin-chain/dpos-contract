// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console2 as console } from "forge-std/console2.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { LibErrorHandler } from "foundry-deployment-kit/libraries/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { Proposal, RoninMigration } from "script/RoninMigration.s.sol";
import { LibString, Contract } from "script/utils/Contract.sol";
import {
  RoninGovernanceAdmin,
  HardForkRoninGovernanceAdminDeploy
} from "script/contracts/HardForkRoninGovernanceAdminDeploy.s.sol";
import {
  RoninTrustedOrganization,
  TemporalRoninTrustedOrganizationDeploy
} from "script/contracts/TemporalRoninTrustedOrganizationDeploy.s.sol";

contract Migration__20232811_ChangeGovernanceAdmin is RoninMigration {
  using LibString for *;
  using LibErrorHandler for bool;
  using stdStorage for StdStorage;
  using LibProxy for address payable;

  /// @dev Array to store proxy targets to change admin
  address[] internal _changeProxyTargets;

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

    // =============================================================================================================================================

    // Get current broken Ronin Governance Admin
    address roninGovernanceAdmin = config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());

    // Deploy temporal Ronin Trusted Organization
    RoninTrustedOrganization tmpTrustedOrg = new TemporalRoninTrustedOrganizationDeploy().run();
    vm.makePersistent(address(tmpTrustedOrg));

    // Deploy new Ronin Governance Admin
    RoninGovernanceAdmin hardForkGovernanceAdmin = new HardForkRoninGovernanceAdminDeploy().run();

    StdStorage storage $;
    assembly {
      // Assign storage slot
      $.slot := stdstore.slot
    }

    // Cheat write into Trusted Organization storage slot with new temporal Trusted Organization contract
    $.target(roninGovernanceAdmin).sig("roninTrustedOrganizationContract()").checked_write(address(tmpTrustedOrg));

    // Get all contracts deployed from the current network
    address payable[] memory addrs = config.getAllAddresses(network());

    // Identify proxy targets to change admin
    for (uint256 i; i < addrs.length; ++i) {
      if (addrs[i].getProxyAdmin() == roninGovernanceAdmin) {
        console.log("Target Proxy to migrate admin", vm.getLabel(addrs[i]));
        _changeProxyTargets.push(addrs[i]);
      }
    }

    address[] memory targets = _changeProxyTargets;
    uint256[] memory values = new uint256[](targets.length);
    bytes[] memory callDatas = new bytes[](targets.length);

    // Build {changeAdmin} calldata to migrate to new Ronin Governance Admin
    for (uint256 i; i < targets.length; ++i) {
      callDatas[i] =
        abi.encodeWithSelector(TransparentUpgradeableProxy.changeAdmin.selector, address(hardForkGovernanceAdmin));
    }

    Proposal.ProposalDetail memory proposal = _buildProposal(
      RoninGovernanceAdmin(roninGovernanceAdmin), block.timestamp + 5 minutes, targets, values, callDatas
    );

    // Execute the proposal
    _executeProposal(RoninGovernanceAdmin(roninGovernanceAdmin), tmpTrustedOrg, proposal);

    // Change broken Ronin Governance Admin to new Ronin Governance Admin
    config.setAddress(network(), Contract.RoninGovernanceAdmin.key(), address(hardForkGovernanceAdmin));

    // Validate new Ronin Governance Admin functionalities by simple upgrade proposals for all related system contracts
    _validateHardForkGovernanceAdmin(targets);
  }

  function _validateHardForkGovernanceAdmin(address[] memory targets)
    internal
    logFn("_validateHardForkGovernanceAdmin")
  {
    for (uint256 i; i < targets.length; ++i) {
      TContract contractType = config.getContractTypeFromCurrentNetwok(targets[i]);
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractType, EMPTY_ARGS);
    }
  }
}

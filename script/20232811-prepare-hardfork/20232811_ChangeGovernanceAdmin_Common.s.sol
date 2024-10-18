// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxyV2 } from "src/extensions/TransparentUpgradeableProxyV2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { IProfile } from "src/interfaces/IProfile.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { Proposal } from "src/libraries/Proposal.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";

abstract contract Migration__20232811_ChangeGovernanceAdmin_Common is RoninMigration {
  using LibProxy for address payable;

  address[] private __scriptProxyTarget;
  address internal __roninGovernanceAdmin;
  address internal __trustedOrg;
  uint256 private _proposalDuration;

  uint256[] __values;
  bytes[] __calldatas;

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
    _proposalDuration = 10 days;

    // Migrate Profile contract for REP-4
    {
      console.log("=============== Begin upgrade ===============");

      uint cooldownTimeChangePubkey = 1 days;

      if (block.chainid == DefaultNetwork.RoninTestnet.chainId()) {
        _proposalDuration = 1 days;

        address profileProxy = loadContract(Contract.Profile.key());
        address gatewayPauseEnforcer = loadContract(Contract.RoninGatewayPauseEnforcer.key());

        // Identify proxy targets to upgrade
        for (uint256 i; i < addrs.length; ++i) {
          address payable adminOfProxy = LibProxy.getProxyAdmin(addrs[i], false);
          if (adminOfProxy == address(__roninGovernanceAdmin)) {
            console.log("Target Proxy to upgrade with proposal", vm.getLabel(addrs[i]));

            address target = addrs[i];
            TContract contractType = vme.getContractTypeFromCurrentNetwork(target);

            // Ignore Pause enforcer
            if (target == gatewayPauseEnforcer) {
              continue;
            }

            if (target == profileProxy) {
              address newProfileLogic = _deployLogic(Contract.Profile.key());

              __scriptProxyTarget.push(target);
              __values.push(0);

              __calldatas.push(
                abi.encodeWithSelector(
                  TransparentUpgradeableProxy.upgradeToAndCall.selector,
                  newProfileLogic,
                  abi.encodeWithSelector(IProfile.initializeV3.selector, cooldownTimeChangePubkey)
                )
              );
            } else {
              address newLogic = _deployLogic(contractType);
              __scriptProxyTarget.push(target);
              __values.push(0);
              __calldatas.push(abi.encodeWithSelector(TransparentUpgradeableProxy.upgradeTo.selector, newLogic));
            }
          } else {
            console.log(
              string.concat(
                StdStyle.yellow(unicode"⚠️ [WARNING] "),
                "Contract ",
                vm.getLabel(addrs[i]),
                " has abnormal admin: ",
                vm.toString(adminOfProxy)
              )
            );
          }
        }

        // Cheat add Profile for community-validator: 0x9687e8C41fa369aD08FD278a43114C4207856a61,  0x32F66d0F9F19Db7b0EF1E9f13160884DA65467e7
        // __scriptProxyTarget.push(profileProxy);
        // __values.push(0);
        // __calldatas.push(
        //   abi.encodeWithSelector(
        //     TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        //     abi.encodeWithSelector(Profile_Testnet.migrateRenouncedCandidate.selector)
        //   )
        // );
      } else if (block.chainid == DefaultNetwork.RoninMainnet.chainId()) {
        _proposalDuration = 10 days;
        // address profileProxy = loadContract(Contract.Profile.key());
        // // Change Profile admin from Bao's EOA to Proxy Admin
        // vm.startPrank(0x4d58Ea7231c394d5804e8B06B1365915f906E27F);
        // TransparentUpgradeableProxy(payable(profileProxy)).changeAdmin(address(__hardForkGovernanceAdmin));
        // vm.stopPrank();
        // // Prepare proposal for Profile
        // address newProfileLogic = _deployLogic(Contract.Profile_Mainnet.key());
        // targets[0] = profileProxy;
        // targets[1] = profileProxy;
        // address stakingContract = loadContract(Contract.Staking.key());
        // callDatas[0] = abi.encodeWithSelector(
        //   TransparentUpgradeableProxy.upgradeToAndCall.selector,
        //   newProfileLogic,
        //   abi.encodeCall(Profile.initializeV2, (stakingContract, __trustedOrg))
        // );
        // callDatas[1] = abi.encodeWithSelector(
        //   TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        //   abi.encodeCall(Profile.initializeV3, (cooldownTimeChangePubkey))
        // );
      }

      // ===============================
      // Propose and execute proposal to upgrade and initialize REP-4
      // ===============================
      if (__scriptProxyTarget[0] != address(0)) {
        console.log("====== Propose and execute proposal to upgrade and initialize REP-4 ======");
        Proposal.ProposalDetail memory proposal = LibProposal.buildProposal(
          IRoninGovernanceAdmin(__roninGovernanceAdmin),
          vm.getBlockTimestamp() + _proposalDuration,
          __scriptProxyTarget,
          __values,
          __calldatas
        );

        // Execute the proposal
        LibProposal.executeProposal(
          IRoninGovernanceAdmin(__roninGovernanceAdmin), IRoninTrustedOrganization(__trustedOrg), proposal
        );
      }

      console.log("=============== End upgrade ===============");
    }
  }
}

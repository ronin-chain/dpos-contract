// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
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
import { Profile_Mainnet } from "@ronin/contracts/ronin/profile/Profile_Mainnet.sol";
import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";

abstract contract Migration__20232811_ChangeGovernanceAdmin_Common is RoninMigration {
  using LibString for *;
  using LibErrorHandler for bool;
  using stdStorage for StdStorage;
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

        address profileProxy = config.getAddressFromCurrentNetwork(Contract.Profile.key());
        address gatewayPauseEnforcer = config.getAddressFromCurrentNetwork(Contract.RoninGatewayPauseEnforcer.key());

        // Identify proxy targets to upgrade
        for (uint256 i; i < addrs.length; ++i) {
          try this.getProxyAdmin(addrs[i]) returns (address payable adminOfProxy) {
            if (adminOfProxy == address(__roninGovernanceAdmin)) {
              console.log("Target Proxy to upgrade with proposal", vm.getLabel(addrs[i]));

              address target = addrs[i];
              TContract contractType = CONFIG.getContractTypeFromCurrentNetwok(target);

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
                    abi.encodeWithSelector(Profile.initializeV3.selector, cooldownTimeChangePubkey)
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
          } catch {}
        }

        // Cheat add Profile for community-validator: 0x9687e8C41fa369aD08FD278a43114C4207856a61,  0x32F66d0F9F19Db7b0EF1E9f13160884DA65467e7
        __scriptProxyTarget.push(profileProxy);
        __values.push(0);
        __calldatas.push(
          abi.encodeWithSelector(
            TransparentUpgradeableProxyV2.functionDelegateCall.selector,
            abi.encodeWithSelector(Profile_Testnet.migrateRenouncedCandidate.selector)
          )
        );
      } else if (block.chainid == DefaultNetwork.RoninMainnet.chainId()) {
        _proposalDuration = 10 days;
        // address profileProxy = config.getAddressFromCurrentNetwork(Contract.Profile.key());
        // // Change Profile admin from Bao's EOA to Proxy Admin
        // vm.startPrank(0x4d58Ea7231c394d5804e8B06B1365915f906E27F);
        // TransparentUpgradeableProxy(payable(profileProxy)).changeAdmin(address(__hardForkGovernanceAdmin));
        // vm.stopPrank();
        // // Prepare proposal for Profile
        // address newProfileLogic = _deployLogic(Contract.Profile_Mainnet.key());
        // targets[0] = profileProxy;
        // targets[1] = profileProxy;
        // address stakingContract = config.getAddressFromCurrentNetwork(Contract.Staking.key());
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
        Proposal.ProposalDetail memory proposal = _buildProposal(
          RoninGovernanceAdmin(__roninGovernanceAdmin),
          block.timestamp + _proposalDuration,
          __scriptProxyTarget,
          __values,
          __calldatas
        );

        // Execute the proposal
        _executeProposal(
          RoninGovernanceAdmin(__roninGovernanceAdmin),
          RoninTrustedOrganization(__trustedOrg),
          proposal
        );
      }

      console.log("=============== End upgrade ===============");
    }
  }
}

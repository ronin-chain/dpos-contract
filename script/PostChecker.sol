// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "foundry-deployment-kit/types/Types.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { BaseMigration } from "foundry-deployment-kit/BaseMigration.s.sol";
import { ScriptExtended } from "foundry-deployment-kit/extensions/ScriptExtended.s.sol";
import { Contract } from "./utils/Contract.sol";
import "./post-check/PostChecker_ApplyCandidate.sol";
import "./post-check/PostChecker_Staking.sol";
import "./post-check/PostChecker_Renounce.sol";
import "./post-check/PostChecker_EmergencyExit.sol";
import "./post-check/PostChecker_Maintenance.sol";
import "./post-check/PostChecker_Slash.sol";

abstract contract PostChecker is
  BaseMigration,
  PostChecker_ApplyCandidate,
  PostChecker_Staking,
  PostChecker_Renounce,
  PostChecker_EmergencyExit,
  PostChecker_Maintenance,
  PostChecker_Slash
{
  using LibProxy for *;
  using LibErrorHandler for bool;

  // @dev Array to store all proxy targets that share same proxy admin
  address[] internal _proxyTargets;

  function run(bytes calldata callData, string calldata command) public override {
    super.run(callData, command);

    console.log(StdStyle.cyan("Post checking..."));
    _postCheckValidatorSet();
    _postCheckGovernanceAdmin();
    _postCheck__ApplyCandidate();
    _postCheck__Staking();
    _postCheck__Renounce();
    _postCheck__EmergencyExit();
    _postCheck__Maintenance();
    _postCheck__Slash();
  }

  function _postCheckValidatorSet() internal logFn("Post check Validator Set") {
    if (address(0x68).code.length == 0) {
      address mockPrecompile = _deployImmutable(Contract.MockPrecompile.key());
      vm.etch(address(0x68), mockPrecompile.code);
      vm.makePersistent(address(0x68));

      vm.etch(address(0x6a), mockPrecompile.code);
      vm.makePersistent(address(0x6a));
    }

    _fastForwardToNextDay();
    _wrapUpEpoch();
    _fastForwardToNextDay();
    _wrapUpEpoch();

    console.log(">", StdStyle.green("Post check Validator `wrapUpEpoch` successful"));
  }

  function _postCheckGovernanceAdmin() internal logFn("Post check Governance Admin") {
    // Get all contracts deployed from the current network
    address payable[] memory addrs = CONFIG.getAllAddresses(network());
    address payable governanceAdmin = CONFIG.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    // Identify proxy targets to upgrade with proposal
    for (uint256 i; i < addrs.length; ++i) {
      try this.getProxyAdmin(addrs[i]) returns (address payable proxy) {
        if (proxy == governanceAdmin) {
          console.log("Target Proxy to test upgrade with proposal", vm.getLabel(addrs[i]));
          _proxyTargets.push(addrs[i]);
        }
      } catch {}
    }
    address[] memory targets = _proxyTargets;
    for (uint256 i; i < targets.length; ++i) {
      TContract contractType = CONFIG.getContractTypeFromCurrentNetwok(targets[i]);
      console.log("Upgrading contract:", vm.getLabel(targets[i]));
      _upgradeProxy(contractType);
    }

    console.log(">", StdStyle.green("Post check Governance Admin Upgrade Proposal successful"));
  }

  function getProxyAdmin(address payable proxy) external returns (address payable proxyAdmin) {
    return proxy.getProxyAdmin();
  }
}

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
import "./post-check/PostChecker_GovernanceAdmin.s.sol";
import "./post-check/PostChecker_ApplyCandidate.sol";
import "./post-check/PostChecker_Staking.sol";
import "./post-check/PostChecker_Renounce.sol";
import "./post-check/PostChecker_EmergencyExit.sol";
import "./post-check/PostChecker_Maintenance.sol";
import "./post-check/PostChecker_Slash.sol";

abstract contract PostChecker is
  BaseMigration,
  PostChecker_ApplyCandidate,
  PostChecker_GovernanceAdmin,
  PostChecker_Staking,
  PostChecker_Renounce,
  PostChecker_EmergencyExit,
  PostChecker_Maintenance,
  PostChecker_Slash
{
  using LibProxy for *;
  using LibErrorHandler for bool;

  function run(bytes calldata callData, string calldata command) public override {
    super.run(callData, command);

    console.log(StdStyle.bold(StdStyle.cyan("\n\n ====================== Post checking... ======================")));

    CONFIG.setUserDefinedConfig(CONFIG.DISABLE_LOG_ARTIFACT(), bytes32(uint256(0x01)));
    CONFIG.setBroadcastDisableStatus(true);
    _setDisableLogProposalStatus(true);

    _postCheckValidatorSet();
    _postCheck__GovernanceAdmin();
    _postCheck__ApplyCandidate();
    _postCheck__Staking();
    _postCheck__Renounce();
    _postCheck__EmergencyExit();
    _postCheck__Maintenance();
    _postCheck__Slash();
    _postCheck__GovernanceAdmin();

    CONFIG.setUserDefinedConfig(CONFIG.DISABLE_LOG_ARTIFACT(), bytes32(uint256(0x00)));
    CONFIG.setBroadcastDisableStatus(false);
    _setDisableLogProposalStatus(false);

    console.log(StdStyle.bold(StdStyle.cyan("\n\n================== Finish post checking ==================\n\n")));
  }

  function _postCheckValidatorSet() internal logPostCheck("[ValidatorSet] wrap up epoch") {
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
  }
}

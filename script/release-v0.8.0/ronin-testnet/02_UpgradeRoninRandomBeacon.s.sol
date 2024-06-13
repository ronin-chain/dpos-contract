// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { Profile } from "@ronin/contracts/ronin/profile/Profile.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";


import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";

import { LibString } from "@solady/utils/LibString.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";

contract Migration_Testnet_Upgrade_RoninRandomBeacon is RoninMigration {
  using LibVRFProof for *;
  using StdStyle for *;

  Profile private profile;
  RoninTrustedOrganization private trustedOrg;
  LibVRFProof.VRFKey[] private keys;

  RoninGovernanceAdmin private roninGovernanceAdmin;
  RoninTrustedOrganization private roninTrustedOrganization;

  uint256 private constant MAX_GV = 4;
  uint256 private constant MAX_RV = 7;
  uint256 private constant MAX_SV = 0;

  address[] private _targets;
  uint256[] private _values;
  bytes[] private _callDatas;

  function run() public {
    roninGovernanceAdmin = RoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    roninTrustedOrganization = RoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    IRandomBeacon.ValidatorType[] memory validatorTypes = new IRandomBeacon.ValidatorType[](4);
    uint256[] memory thresholds = new uint256[](4);

    validatorTypes[0] = IRandomBeacon.ValidatorType.Governing;
    validatorTypes[1] = IRandomBeacon.ValidatorType.Standard;
    validatorTypes[2] = IRandomBeacon.ValidatorType.Rotating;
    validatorTypes[3] = IRandomBeacon.ValidatorType.All;

    thresholds[0] = MAX_GV;
    thresholds[1] = MAX_SV;
    thresholds[2] = MAX_RV;
    thresholds[3] = MAX_GV + MAX_SV + MAX_RV;

    _targets.push(address(loadContract(Contract.RoninRandomBeacon.key())));
    _values.push(0);
    _callDatas.push(
      abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        (abi.encodeCall(IRandomBeacon.bulkSetValidatorThresholds, (validatorTypes, thresholds)))
      )
    );

    Proposal.ProposalDetail memory proposal =
      LibProposal.buildProposal(roninGovernanceAdmin, vm.getBlockTimestamp() + 14 days, _targets, _values, _callDatas);
    LibProposal.executeProposal(roninGovernanceAdmin, roninTrustedOrganization, proposal);
  }
}

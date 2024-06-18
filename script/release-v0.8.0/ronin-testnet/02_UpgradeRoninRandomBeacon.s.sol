// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IRoninGovernanceAdmin } from "@ronin/contracts/interfaces/IRoninGovernanceAdmin.sol";

import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";

import { StdStyle } from "forge-std/StdStyle.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";

import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";

contract Migration_Testnet_Upgrade_RoninRandomBeacon is RoninMigration {
  using LibVRFProof for *;
  using StdStyle for *;

  IProfile private profile;
  IRoninTrustedOrganization private trustedOrg;
  LibVRFProof.VRFKey[] private keys;

  IRoninGovernanceAdmin private roninGovernanceAdmin;
  IRoninTrustedOrganization private roninTrustedOrganization;

  uint256 private constant MAX_GV = 4;
  uint256 private constant MAX_RV = 7;
  uint256 private constant MAX_SV = 0;

  address[] private _targets;
  uint256[] private _values;
  bytes[] private _callDatas;

  function run() public {
    roninGovernanceAdmin = IRoninGovernanceAdmin(loadContract(Contract.RoninGovernanceAdmin.key()));
    roninTrustedOrganization = IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

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

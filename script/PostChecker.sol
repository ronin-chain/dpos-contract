// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { HasContracts } from "@ronin/contracts/extensions/collections/HasContracts.sol";
import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { RoninRandomBeacon } from "@ronin/contracts/ronin/random-beacon/RoninRandomBeacon.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { ContractType } from "contracts/utils/ContractType.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract } from "@fdk/types/Types.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { ScriptExtended } from "@fdk/extensions/ScriptExtended.s.sol";
import { Contract } from "./utils/Contract.sol";
import { PostChecker_GovernanceAdmin } from "./post-check/PostChecker_GovernanceAdmin.s.sol";
import { PostChecker_ApplyCandidate } from "./post-check/PostChecker_ApplyCandidate.sol";
import { PostChecker_Staking } from "./post-check/PostChecker_Staking.sol";
import { PostChecker_Renounce } from "./post-check/PostChecker_Renounce.sol";
import { PostChecker_EmergencyExit } from "./post-check/PostChecker_EmergencyExit.sol";
import { PostChecker_Maintenance } from "./post-check/PostChecker_Maintenance.sol";
import { PostChecker_Slash } from "./post-check/PostChecker_Slash.sol";
import { RoninMigration } from "./RoninMigration.s.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { LibPrecompile } from "script/shared/libraries/LibPrecompile.sol";
import { LibVRFProof } from "script/shared/libraries/LibVRFProof.sol";
import { ProxyInterface } from "@fdk/libraries/LibDeploy.sol";

contract PostChecker is
  RoninMigration,
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

  uint256 internal constant MAX_GOV_PERCENTAGE = 10;

  function _postCheck() internal virtual override(ScriptExtended, RoninMigration) {
    RoninMigration._postCheck();
  }

  function _getProxyAdmin() internal view virtual override(BaseMigration, RoninMigration) returns (address payable) {
    return payable(RoninMigration._getProxyAdminFromCurrentNetwork());
  }

  function upgradeCallback(
    address proxy,
    address logic,
    uint256 callValue,
    bytes memory callData,
    ProxyInterface proxyInterface
  ) public virtual override(BaseMigration, RoninMigration) {
    super.upgradeCallback(proxy, logic, callValue, callData, proxyInterface);
  }

  function _upgradeProxy(
    TContract contractType,
    bytes memory args,
    bytes memory argsLogicConstructor
  ) internal virtual override(BaseMigration, RoninMigration) returns (address payable) {
    return RoninMigration._upgradeProxy(contractType, args, argsLogicConstructor);
  }

  function _deployProxy(TContract contractType)
    internal
    virtual
    override(BaseMigration, RoninMigration)
    returns (address payable)
  {
    return RoninMigration._deployProxy(contractType);
  }

  function run() public virtual {
    console.log(StdStyle.bold(StdStyle.cyan("\n\n ====================== Post checking... ======================")));

    _postCheck__ValidatorSet();
    _postCheck__GovernanceAdmin();
    _postCheck__ApplyCandidate();
    _postCheck__Staking();
    _postCheck__Renounce();
    _postCheck__EmergencyExit();
    _postCheck__Maintenance();
    _postCheck__Slash();
    _postCheck__GovernanceAdmin();

    console.log(StdStyle.bold(StdStyle.cyan("\n\n================== Finish post checking ==================\n\n")));
  }

  function _postCheck__ValidatorSet() internal logPostCheck("[ValidatorSet] wrap up epoch") {
    LibPrecompile.deployPrecompile();

    IProfile profile = IProfile(loadContract(Contract.Profile.key()));
    IRoninTrustedOrganization trustedOrg =
      IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key()));

    address governanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    uint256 gvToRemove = allTrustedOrgs.length - 1;
    if (gvToRemove != 0) {
      TConsensus[] memory consensusesToRemove = new TConsensus[](gvToRemove);
      for (uint256 i = allTrustedOrgs.length - 1; i >= 1; --i) {
        uint256 j = allTrustedOrgs.length - 1 - i;
        consensusesToRemove[j] = allTrustedOrgs[i].consensusAddr;
        if (i == 1) break;
      }

      vm.prank(governanceAdmin);
      TransparentUpgradeableProxyV2(payable(address(trustedOrg))).functionDelegateCall(
        abi.encodeCall(trustedOrg.removeTrustedOrganizations, (consensusesToRemove))
      );
    }

    allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    LibVRFProof.VRFKey[] memory vrfKeys = LibVRFProof.genVRFKeys(allTrustedOrgs.length);
    config.setUserDefinedConfig("vrf-keys", abi.encode(vrfKeys));

    for (uint256 i; i < vrfKeys.length; ++i) {
      address cid = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
      address admin = profile.getId2Admin(cid);

      vm.prank(admin);
      profile.changeVRFKeyHash(cid, vrfKeys[i].keyHash);
    }

    console.log(StdStyle.green("Cheat fast forward to 2 days ..."));
    LibWrapUpEpoch.wrapUpPeriods({ times: 2, shouldSubmitBeacon: false });

    LibWrapUpEpoch.wrapUpPeriods(3);
  }
}

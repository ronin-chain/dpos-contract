// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICandidateStaking } from "@ronin/contracts/interfaces/staking/ICandidateStaking.sol";
import { IProfile } from "@ronin/contracts/interfaces/IProfile.sol";
import { IRoninValidatorSet } from "@ronin/contracts/interfaces/validator/IRoninValidatorSet.sol";
import { IStakingVesting } from "@ronin/contracts/interfaces/IStakingVesting.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";
import { IRoninTrustedOrganization } from "@ronin/contracts/interfaces/IRoninTrustedOrganization.sol";
import { TConsensus } from "@ronin/contracts/udvts/Types.sol";
import { ContractType } from "contracts/utils/ContractType.sol";
import { ITransparentUpgradeableProxyV2 } from
  "@ronin/contracts/interfaces/extensions/ITransparentUpgradeableProxyV2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
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
  using StdStyle for *;

  TConsensus internal _gvToCheatVRF;
  TConsensus[] internal _gvsToRemove;

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
    IRandomBeacon randomBeacon = IRandomBeacon(loadContract(Contract.RoninRandomBeacon.key()));
    IRoninValidatorSet validatorSet = IRoninValidatorSet(loadContract(Contract.RoninValidatorSet.key()));
    IStakingVesting stakingVesting = IStakingVesting(loadContract(Contract.StakingVesting.key()));

    address governanceAdmin = loadContract(Contract.RoninGovernanceAdmin.key());
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    uint256 gvToRemove = allTrustedOrgs.length - 1;
    if (gvToRemove != 0) {
      for (uint256 i; i < allTrustedOrgs.length; ++i) {
        if (validatorSet.isValidatorCandidate(allTrustedOrgs[i].consensusAddr)) {
          _gvToCheatVRF = allTrustedOrgs[i].consensusAddr;
          break;
        }
      }

      for (uint256 i; i < allTrustedOrgs.length; ++i) {
        if (allTrustedOrgs[i].consensusAddr == _gvToCheatVRF) continue;
        _gvsToRemove.push(allTrustedOrgs[i].consensusAddr);
      }

      vm.startPrank(governanceAdmin);
      ITransparentUpgradeableProxyV2(address(trustedOrg)).functionDelegateCall(
        abi.encodeCall(trustedOrg.removeTrustedOrganizations, (_gvsToRemove))
      );
      // Update change cooldown to 0 in case GV update their VRF key recently
      ITransparentUpgradeableProxyV2(address(profile)).functionDelegateCall(
        abi.encodeCall(IProfile.setCooldownConfig, (0))
      );
      vm.stopPrank();
    }

    allTrustedOrgs = trustedOrg.getAllTrustedOrganizations();
    LibVRFProof.VRFKey[] memory vrfKeys = LibVRFProof.genVRFKeys(allTrustedOrgs.length);
    config.setUserDefinedConfig("vrf-keys", abi.encode(vrfKeys));

    for (uint256 i; i < vrfKeys.length; ++i) {
      address cid = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
      address admin;
      try profile.getId2Admin(cid) returns (address adm) {
        admin = adm;
      } catch {
        admin = profile.getId2Profile(cid).admin;
      }

      vm.prank(admin);
      profile.changeVRFKeyHash(cid, vrfKeys[i].keyHash);
    }

    console.log(StdStyle.green("Cheat fast forward to 2 epochs ..."));
    LibWrapUpEpoch.wrapUpEpoch();
    LibWrapUpEpoch.wrapUpEpoch();

    uint256 activatedAtPeriod = randomBeacon.getActivatedAtPeriod();
    uint256 currPeriod = validatorSet.currentPeriod();
    if (currPeriod < activatedAtPeriod) {
      console.log(
        StdStyle.green("Cheat fast forward to activated period for number of periods:"), activatedAtPeriod - currPeriod
      );
      LibWrapUpEpoch.wrapUpPeriods({ times: activatedAtPeriod - currPeriod, shouldSubmitBeacon: false });
      console.log("Expected Switch Logic to REP10 Logic".yellow());
      console.log("Logic now:".yellow(), address(validatorSet).getProxyImplementation());

      console.log("Submitting block reward at next block number after REP10 activated...".yellow());

      TConsensus[] memory blockProducers = validatorSet.getBlockProducers();
      uint256 currUnixTimestamp;
      TConsensus randomProducer = blockProducers[currUnixTimestamp % blockProducers.length];
      vm.coinbase(TConsensus.unwrap(randomProducer));
      vme.rollUpTo(vm.getBlockNumber() + 1);
      vm.prank(TConsensus.unwrap(randomProducer));
      vm.recordLogs();
      validatorSet.submitBlockReward{ value: 0.5 ether }();

      VmSafe.Log[] memory logs = vm.getRecordedLogs();
      bool emitted;
      uint256 newPercentage;
      uint256 rep10Period;
      for (uint256 i; i < logs.length; ++i) {
        if (
          logs[i].emitter == address(stakingVesting)
            && logs[i].topics[0] == IStakingVesting.REP10FastFinalityRewardActivated.selector
        ) {
          emitted = true;
          (rep10Period, newPercentage) = abi.decode(logs[i].data, (uint256, uint256));
          console.log("Fast Finality Reward Percentage", newPercentage, "Period:", rep10Period);
        }
      }

      assertTrue(emitted, "REP10FastFinalityRewardActivated event not emitted");
      assertEq(stakingVesting.fastFinalityRewardPercentage(), newPercentage, "REP10 percentage not match");
      assertEq(rep10Period, activatedAtPeriod, "REP10 period not match");

      randomProducer = blockProducers[currUnixTimestamp % blockProducers.length];
      vm.coinbase(TConsensus.unwrap(randomProducer));
      vme.rollUpTo(vm.getBlockNumber() + 1);
      vm.prank(TConsensus.unwrap(randomProducer));
      vm.recordLogs();
      validatorSet.submitBlockReward{ value: 1 ether }();
    }

    console.log(StdStyle.green("Cheat fast forward to 1 epoch ..."));
    LibWrapUpEpoch.wrapUpEpoch();
  }
}

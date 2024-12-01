// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../REP-10_Base.t.sol";

contract REP_10_FastFinalityTrackingTest is REP10_BaseTest {
  using StdStyle for *;
  using LibArray for uint256[];

  struct Delegator {
    address addr;
    uint256 vIdx;
    uint256 amt;
  }

  struct Validator {
    address adm;
    address css;
    uint256 amt;
    bool gv;
    uint256 vRate; // vote rate
    uint256 cRate; // commission rate
  }

  uint256 private blockBonus = 0;
  uint256 private fastFinalityRewardPercentage = 8500;
  Delegator[] private delegators;
  Validator[] private validators;
  mapping(address css => address adm) private cssToAdm;
  mapping(address adm => uint256) private admBalance;
  mapping(address adm => uint256) private admCRate;
  mapping(address css => uint256) private cssIdx;

  function setUp() public virtual override {
    _setUpDPoSDeployHelper();
    _setUpValidatorAndDelegatorData();
    _loadContracts();
    _overrideThresholdConfigs();
    _overrideRewardConfig();
    _addGoverningValidators();
    _applyValidatorCandidates();
    _cheatAddVRFKeysForGoverningValidators();
    _delegate();
    _cheatTime();
  }

  function _overrideThresholdConfigs() private {
    IRandomBeacon.ValidatorType[] memory vTypes = new IRandomBeacon.ValidatorType[](4);
    vTypes[0] = IRandomBeacon.ValidatorType.Governing;
    vTypes[1] = IRandomBeacon.ValidatorType.Standard;
    vTypes[2] = IRandomBeacon.ValidatorType.Rotating;
    vTypes[3] = IRandomBeacon.ValidatorType.All;

    uint256[] memory vThresholds = new uint256[](4);
    vThresholds[0] = 5;
    vThresholds[1] = 0;
    vThresholds[2] = 5;
    vThresholds[3] = 10;

    vm.prank(address(governanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(roninRandomBeacon))).functionDelegateCall(
      abi.encodeCall(IRandomBeacon.bulkSetValidatorThresholds, (vTypes, vThresholds))
    );
  }

  function _overrideRewardConfig() private {
    vm.startPrank(address(governanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(stakingVesting))).functionDelegateCall(
      abi.encodeCall(IStakingVesting.setBlockProducerBonusPerBlock, (blockBonus))
    );
    TransparentUpgradeableProxyV2(payable(address(stakingVesting))).functionDelegateCall(
      abi.encodeCall(IStakingVesting.setFastFinalityRewardPercentage, (fastFinalityRewardPercentage))
    );
    vm.stopPrank();
  }

  function _setUpValidatorAndDelegatorData() private {
    Delegator[10] memory mDelegators = [
      Delegator({ addr: makeAddr("dlg-css-02"), vIdx: 2, amt: 263 ether }),
      Delegator({ addr: makeAddr("dlg-css-08"), vIdx: 8, amt: 245 ether }),
      Delegator({ addr: makeAddr("dlg-css-11"), vIdx: 11, amt: 384 ether }),
      Delegator({ addr: makeAddr("dlg-css-03"), vIdx: 3, amt: 401 ether }),
      Delegator({ addr: makeAddr("dlg-css-07"), vIdx: 7, amt: 155 ether }),
      Delegator({ addr: makeAddr("dlg-css-10"), vIdx: 10, amt: 350 ether }),
      Delegator({ addr: makeAddr("dlg-css-00"), vIdx: 0, amt: 148 ether }),
      Delegator({ addr: makeAddr("dlg-css-11"), vIdx: 11, amt: 392 ether }),
      Delegator({ addr: makeAddr("dlg-css-10"), vIdx: 10, amt: 200 ether }),
      Delegator({ addr: makeAddr("dlg-css-11"), vIdx: 11, amt: 455 ether })
    ];
    for (uint256 i; i < mDelegators.length; i++) {
      delegators.push(mDelegators[i]);
    }

    Validator[13] memory mValidators = [
      Validator({ adm: makeAddr("adm-00"), css: makeAddr("css-00"), amt: 6904 ether, gv: true, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-01"), css: makeAddr("css-01"), amt: 9014 ether, gv: true, vRate: 100, cRate: 1000 }),
      Validator({ adm: makeAddr("adm-02"), css: makeAddr("css-02"), amt: 7812 ether, gv: true, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-03"), css: makeAddr("css-03"), amt: 9180 ether, gv: true, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-04"), css: makeAddr("css-04"), amt: 7362 ether, gv: true, vRate: 100, cRate: 2000 }),
      Validator({ adm: makeAddr("adm-05"), css: makeAddr("css-05"), amt: 7210 ether, gv: false, vRate: 100, cRate: 2000 }),
      Validator({ adm: makeAddr("adm-06"), css: makeAddr("css-06"), amt: 5611 ether, gv: false, vRate: 80, cRate: 500 }),
      Validator({ adm: makeAddr("adm-07"), css: makeAddr("css-07"), amt: 7212 ether, gv: false, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-08"), css: makeAddr("css-08"), amt: 6277 ether, gv: false, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-09"), css: makeAddr("css-09"), amt: 6579 ether, gv: false, vRate: 90, cRate: 500 }),
      Validator({ adm: makeAddr("adm-10"), css: makeAddr("css-10"), amt: 7380 ether, gv: false, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-11"), css: makeAddr("css-11"), amt: 6066 ether, gv: false, vRate: 100, cRate: 500 }),
      Validator({ adm: makeAddr("adm-12"), css: makeAddr("css-12"), amt: 5218 ether, gv: false, vRate: 100, cRate: 500 })
    ];

    for (uint256 i; i < mValidators.length; i++) {
      validators.push(mValidators[i]);
      cssToAdm[mValidators[i].css] = mValidators[i].adm;
      admCRate[mValidators[i].adm] = mValidators[i].cRate;
      cssIdx[mValidators[i].css] = i;
    }
  }

  function _addGoverningValidators() private {
    IRoninTrustedOrganization.TrustedOrganization[] memory currGVs =
      roninTrustedOrganization.getAllTrustedOrganizations();
    TConsensus[] memory currCss = new TConsensus[](currGVs.length);
    for (uint256 i; i < currGVs.length; i++) {
      currCss[i] = currGVs[i].consensusAddr;
    }

    IRoninTrustedOrganization.TrustedOrganization[] memory newGVs =
      new IRoninTrustedOrganization.TrustedOrganization[](validators.length);

    uint256 count;

    for (uint256 i; i < validators.length; i++) {
      if (validators[i].gv) {
        newGVs[count++] = IRoninTrustedOrganization.TrustedOrganization({
          governor: makeAddr(string.concat("gv-", vm.toString(i))),
          __deprecatedBridgeVoter: address(0),
          addedBlock: 0,
          consensusAddr: TConsensus.wrap(validators[i].css),
          weight: 100
        });
      }
    }

    assembly {
      mstore(newGVs, count)
    }

    vm.startPrank(address(governanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(roninTrustedOrganization))).functionDelegateCall(
      abi.encodeCall(IRoninTrustedOrganization.addTrustedOrganizations, (newGVs))
    );
    TransparentUpgradeableProxyV2(payable(address(roninTrustedOrganization))).functionDelegateCall(
      abi.encodeCall(IRoninTrustedOrganization.removeTrustedOrganizations, (currCss))
    );
    vm.stopPrank();
  }

  function _applyValidatorCandidates() private {
    for (uint256 i; i < validators.length; ++i) {
      vm.deal(validators[i].adm, validators[i].amt);
      vm.deal(validators[i].css, 1000 ether);
      vm.prank(validators[i].adm);
      staking.applyValidatorCandidate{ value: validators[i].amt }(
        validators[i].adm,
        TConsensus.wrap(validators[i].css),
        payable(validators[i].adm),
        validators[i].cRate,
        bytes(string.concat("pubKey-", vm.getLabel(validators[i].css))),
        ""
      );
    }
  }

  function _delegate() private {
    for (uint256 i; i < delegators.length; ++i) {
      vm.deal(delegators[i].addr, delegators[i].amt);
      vm.prank(delegators[i].addr);
      staking.delegate{ value: delegators[i].amt }(TConsensus.wrap(validators[delegators[i].vIdx].css));
    }
  }

  function _cheatAddVRFKeysForGoverningValidators() internal {
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs =
      roninTrustedOrganization.getAllTrustedOrganizations();
    LibVRFProof.VRFKey[] memory vrfKeys = LibVRFProof.genVRFKeys(allTrustedOrgs.length);
    vme.setUserDefinedConfig("vrf-keys", abi.encode(vrfKeys));

    for (uint256 i; i < vrfKeys.length; ++i) {
      address cid = profile.getConsensus2Id(allTrustedOrgs[i].consensusAddr);
      address admin = profile.getId2Admin(cid);
      vm.broadcast(admin);
      profile.changeVRFKeyHash(cid, vrfKeys[i].keyHash);
    }
  }

  function _cheatTime() internal override {
    uint256 currUnixTime = vm.unixTime() / 1000;
    uint256 currPeriod = _computePeriod(currUnixTime);
    uint256 startPeriodTimestamp = PERIOD_DURATION * (currPeriod + 9);

    vm.warp(startPeriodTimestamp);
    vm.roll(1000);

    LibWrapUpEpoch.wrapUpEpoch();
    LibWrapUpEpoch.wrapUpPeriods({ times: 1, shouldSubmitBeacon: false });

    vm.warp(PERIOD_DURATION * (currPeriod + 10));
  }

  function testREP10Concrete_FastFinalityRewardSharing_FullVote_MustBeCorrect() external {
    console.log("Start testREP10Concrete_FastFinalityRewardSharing_MustBeCorrect...".green());
    uint256 currPeriod = roninValidatorSet.currentPeriod();
    uint256 currPeriodStartedAtBlock = roninValidatorSet.currentPeriodStartAtBlock();
    uint256 currBlockNumber = vm.getBlockNumber();
    uint256 numberOfBlocksInEpoch = roninValidatorSet.numberOfBlocksInEpoch();

    console.log("Start Period:".yellow(), currPeriod);
    console.log("Start Epoch:".yellow(), roninValidatorSet.epochOf(vm.getBlockNumber()));
    console.log("Start Block Of Period:".yellow(), currPeriodStartedAtBlock);
    console.log("Start Block Number:".yellow(), currBlockNumber);
    console.log("Number Of Blocks In Epoch:".yellow(), numberOfBlocksInEpoch);

    vm.deal(address(roninValidatorSet), 10_000_000 ether);
    vm.deal(address(stakingVesting), 100_000_000 ether);

    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    console.log("Candidate Count".yellow(), allConsensuses.length);
    VmSafe.Log[] memory logs;

    // Record balance before for validator
    for (uint256 i; i < validators.length; ++i) {
      admBalance[validators[i].adm] = validators[i].adm.balance;
      console.log(
        "Validator: ".yellow(),
        vm.getLabel(validators[i].adm),
        "Balance: ".yellow(),
        vm.toString(validators[i].adm.balance)
      );
    }

    for (uint256 i; i < 144; ++i) {
      TConsensus[] memory blockProducers = roninValidatorSet.getBlockProducers();
      string memory blockProducerStr = "";
      for (uint256 j; j < blockProducers.length; ++j) {
        blockProducerStr =
          string.concat(blockProducerStr, vm.toString(cssIdx[TConsensus.unwrap(blockProducers[j])]), ", ");
      }
      blockProducerStr = string.concat("[", blockProducerStr, "]");
      console.log("Block Producers:", blockProducerStr);

      for (uint256 j; j < numberOfBlocksInEpoch; ++j) {
        vm.coinbase(TConsensus.unwrap(blockProducers[j % blockProducers.length]));
        vm.startPrank(block.coinbase);

        fastFinalityTracking.recordFinality(allConsensuses);
        roninValidatorSet.submitBlockReward{ value: 10_000 }();

        vm.stopPrank();

        vm.roll(vm.getBlockNumber() + 1);
        vm.warp(vm.getBlockTimestamp() + 3);
      }

      console.log(
        "Period:", _computePeriod(vm.getBlockTimestamp()), "Epoch:", roninValidatorSet.epochOf(vm.getBlockNumber())
      );
      vm.prank(block.coinbase);
      vm.recordLogs();
      roninValidatorSet.wrapUpEpoch();
      logs = vm.getRecordedLogs();
    }

    uint256 sumValidatorReward;
    uint256 sumDelegatorReward;
    address[] memory cids;
    uint256[] memory ffAmounts;
    uint256[] memory bmAmounts;
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].emitter == address(roninValidatorSet)) {
        if (logs[i].topics[0] == ICoinbaseExecution.FastFinalityRewardDelegatorsDistributed.selector) {
          (cids, ffAmounts) = abi.decode(logs[i].data, (address[], uint256[]));
          uint256 total = ffAmounts.sum();
          sumDelegatorReward += total;
          console.log("Total FF Delegator Reward:", total.green());

          for (uint256 j; j < cids.length; ++j) {
            console.log("FF Delegator Reward:", vm.getLabel(cids[j]), "Amount:", vm.toString(ffAmounts[j]).green());
          }
        }
        if (logs[i].topics[0] == ICoinbaseExecution.MiningRewardDelegatorsDistributed.selector) {
          (cids, bmAmounts) = abi.decode(logs[i].data, (address[], uint256[]));
          uint256 total = bmAmounts.sum();
          sumDelegatorReward += total;
          console.log("Total BM Delegator Reward:", total.green());

          for (uint256 j; j < cids.length; ++j) {
            console.log("BM Delegator Reward:", vm.getLabel(cids[j]), "Amount:", vm.toString(bmAmounts[j]).green());
          }
        }
      }
    }
    uint256[] memory delegatorRewards = LibArray.add(ffAmounts, bmAmounts);
    for (uint256 i; i < cids.length; ++i) {
      address adm = cssToAdm[cids[i]];
      uint256 validatorReward = adm.balance - admBalance[adm];
      sumValidatorReward += validatorReward;
      console.log(
        string.concat(
          " Validator: ",
          vm.getLabel(adm),
          " CRate: ",
          vm.toString(admCRate[adm]),
          " Commission Reward: ",
          vm.toString(validatorReward).green(),
          " Delegator Reward: ",
          vm.toString(delegatorRewards[i]).green(),
          " Total Reward: ",
          vm.toString(validatorReward + delegatorRewards[i]).green()
        )
      );
    }

    console.log("Sum Validator Reward:", sumValidatorReward.green());
    console.log("Sum Delegator Reward:", sumDelegatorReward.green());
    console.log("Total Reward:", vm.toString(sumValidatorReward + sumDelegatorReward).green());
  }

  function testREP10Fuzz_recordVoters_ScoresNeverZero(
    uint256 numPick
  ) external {
    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    numPick = bound(numPick, 1, allConsensuses.length);

    // Shuffle all validators
    for (uint256 i = allConsensuses.length - 1; i > 0; i--) {
      uint256 j = vm.unixTime() % (i + 1);
      TConsensus temp = allConsensuses[i];
      allConsensuses[i] = allConsensuses[j];
      allConsensuses[j] = temp;
    }

    // Pick random validators
    TConsensus[] memory pickedConsensuses = new TConsensus[](numPick);

    for (uint256 i = 0; i < numPick; i++) {
      pickedConsensuses[i] = allConsensuses[i];
    }

    uint256 currEpoch = roninValidatorSet.epochOf(vm.getBlockNumber());

    // Record voters
    vm.prank(block.coinbase);
    fastFinalityTracking.recordFinality(pickedConsensuses);
    uint256[] memory scores = fastFinalityTracking.getManyFinalityScores(currEpoch, pickedConsensuses);
    // Assert scores never zero
    for (uint256 i; i < numPick; i++) {
      assertTrue(scores[i] > 0, "Score should never be zero");
    }
  }

  function testREP10Fuzz_recordVoters_CountsNeverZero(
    uint256 numPick
  ) external {
    TConsensus[] memory allConsensuses = roninValidatorSet.getValidatorCandidates();
    numPick = bound(numPick, 1, allConsensuses.length);

    // Shuffle all validators
    for (uint256 i = allConsensuses.length - 1; i > 0; i--) {
      uint256 j = vm.unixTime() % (i + 1);
      TConsensus temp = allConsensuses[i];
      allConsensuses[i] = allConsensuses[j];
      allConsensuses[j] = temp;
    }

    // Pick random validators
    TConsensus[] memory pickedConsensuses = new TConsensus[](numPick);

    for (uint256 i = 0; i < numPick; i++) {
      pickedConsensuses[i] = allConsensuses[i];
    }

    uint256 currEpoch = roninValidatorSet.epochOf(vm.getBlockNumber());

    // Record voters
    vm.prank(block.coinbase);
    fastFinalityTracking.recordFinality(pickedConsensuses);
    uint256[] memory counts = fastFinalityTracking.getManyFinalityVoteCounts(currEpoch, pickedConsensuses);
    // Assert counts never zero
    for (uint256 i; i < numPick; i++) {
      assertTrue(counts[i] > 0, "Count should never be zero");
    }
  }
}

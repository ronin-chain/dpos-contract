// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./REP10_Config_Mainnet_Base.s.sol";

contract Migration__04_ProposeAndExecuteProposalBatch_ShadowMainnet_Release_V0_8_1B is REP10_Config_Mainnet_Base {
  using LibProxy for *;
  using StdStyle for *;

  uint256 internal constant FAST_FINALITY_REWARD_PERCENTAGE = 8500;
  uint256 internal constant NEW_RANDOM_BEACON_UNAVAILABLE_SLASH_THRESHOLD = 5;

  Proposal.ProposalDetail internal _proposal;

  function run() public virtual override onlyOn(Network.ShadowForkMainnet.key()) {
    super.run();
    roninRandomBeacon = IRandomBeacon(loadContract(Contract.RoninRandomBeacon.key()));
    vm.chainId(2020);

    _deployRoninValidatorSetREP10MigratorLogic();

    _targets = [address(roninValidatorSet), address(stakingVesting), address(roninRandomBeacon)];
    _values = [0, 0, 0];
    _callDatas = [
      abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (roninValidatorSetREP10LogicMigrator)),
      abi.encodeCall(
        TransparentUpgradeableProxy.upgradeToAndCall,
        (
          _deployLogic(Contract.StakingVesting.key()),
          abi.encodeCall(IStakingVesting.initializeV4, (REP10_ACTIVATION_PERIOD, FAST_FINALITY_REWARD_PERCENTAGE))
        )
      ),
      abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        (abi.encodeCall(IRandomBeacon.setUnavailabilitySlashThreshold, (NEW_RANDOM_BEACON_UNAVAILABLE_SLASH_THRESHOLD)))
      )
    ];

    for (uint256 i; i < _targets.length; ++i) {
      console.log("Target:", i, vm.toString(_targets[i]));
    }

    for (uint256 i; i < _callDatas.length; ++i) {
      console.log("CallData:", i, vm.toString(_callDatas[i]));
    }

    for (uint256 i; i < _values.length; ++i) {
      console.log("Value:", i, vm.toString(_values[i]));
    }

    _proposal =
      LibProposal.buildProposal(roninGovernanceAdmin, vm.getBlockTimestamp() + 3 hours, _targets, _values, _callDatas);
    LibProposal.executeProposal(roninGovernanceAdmin, roninTrustedOrganization, _proposal);
  }

  function _deployRoninValidatorSetREP10MigratorLogic() internal {
    address payable prevMigrator = address(roninValidatorSet).getProxyImplementation();
    address prevLogic = RoninValidatorSetREP10Migrator(prevMigrator).PREV_IMPL();

    console.log("Verify Link:", string.concat("https://app.roninchain.com/address/", vm.toString(prevLogic)));
    assertTrue(prevLogic.code.length != 0, "Prev Logic is not a contract");
    assertTrue(IRoninValidatorSet(prevLogic).currentPeriod() == 0, "Cannot interact with prev logic");

    roninValidatorSetREP10LogicMigrator = new RoninValidatorSetREP10MigratorLogicDeploy().overrideActivatedAtPeriod(
      REP10_ACTIVATION_PERIOD
    ).overridePrevImpl(prevLogic).run();
  }

  function _postCheck() internal virtual override {
    // Validate Data Correctness
    uint256 rep10ActivationPeriod = roninRandomBeacon.getActivatedAtPeriod();
    (,, uint256 slashAmount,) = slashIndicator.getUnavailabilitySlashingConfigs();

    console.log("[Ronin Validator Set] Current Period".green(), roninValidatorSet.currentPeriod());

    console.log("[Slash Indicator] Unavailability Slash Amount:".yellow(), slashAmount / 1 ether, "RON");
    console.log(
      "[Slash Indicator] Ronin Random Beacon Slash Amount:".yellow(),
      slashIndicator.getRandomBeaconSlashingConfigs()._slashAmount / 1 ether,
      "RON"
    );
    console.log(
      "[Slash Indicator] Slash Random Beacon Activated At Period:".yellow(),
      slashIndicator.getRandomBeaconSlashingConfigs()._activatedAtPeriod
    );
    console.log(
      "[Ronin Random Beacon] REP-10 Ronin Random Beacon Activated At Period".yellow(),
      roninRandomBeacon.getActivatedAtPeriod()
    );
    console.log(
      "[Ronin Random Beacon] Slash Threshold:".yellow(), roninRandomBeacon.getUnavailabilitySlashThreshold(), "times"
    );
    console.log(
      "[Ronin Random Beacon] Max GV".yellow(),
      roninRandomBeacon.getValidatorThreshold(IRandomBeacon.ValidatorType.Governing)
    );
    console.log(
      "[Ronin Random Beacon] Max SV".yellow(),
      roninRandomBeacon.getValidatorThreshold(IRandomBeacon.ValidatorType.Standard)
    );
    console.log(
      "[Ronin Random Beacon] Max RV".yellow(),
      roninRandomBeacon.getValidatorThreshold(IRandomBeacon.ValidatorType.Rotating)
    );
    console.log("[Ronin Random Beacon] Cooldown Threshold".yellow(), roninRandomBeacon.COOLDOWN_PERIOD_THRESHOLD());
    console.log(
      "[Ronin Validator Set] REP-10 Activated At Period".yellow(),
      RoninValidatorSetREP10Migrator(payable(address(roninValidatorSetREP10LogicMigrator))).ACTIVATED_AT_PERIOD()
    );
    console.log("[Ronin Validator Set] Max Validator Candidate".yellow(), roninValidatorSet.maxValidatorCandidate());
    console.log("[Ronin Validator Set] Max Validator Number:".yellow(), roninValidatorSet.maxValidatorNumber());

    assertTrue(rep10ActivationPeriod > roninValidatorSet.currentPeriod(), "Invalid activated period for random beacon");
    assertEq(
      rep10ActivationPeriod,
      RoninValidatorSetREP10Migrator(payable(address(roninValidatorSetREP10LogicMigrator))).ACTIVATED_AT_PERIOD(),
      "[RoninValidatorSet] Invalid REP-10 activation period"
    );
    assertEq(roninValidatorSet.maxValidatorNumber(), 22, "[RoninValidatorSet] Invalid max validator number");
    assertEq(rep10ActivationPeriod, REP10_ACTIVATION_PERIOD, "[RoninRandomBeacon] Invalid activated period");

    assertEq(
      roninRandomBeacon.getUnavailabilitySlashThreshold(),
      NEW_RANDOM_BEACON_UNAVAILABLE_SLASH_THRESHOLD,
      "[RoninRandomBeacon] Invalid slash threshold"
    );
    assertEq(
      rep10ActivationPeriod,
      slashIndicator.getRandomBeaconSlashingConfigs()._activatedAtPeriod,
      "[SlashIndicator] Invalid activated period for random beacon"
    );
    assertEq(
      SLASH_RANDOM_BEACON_AMOUNT,
      slashIndicator.getRandomBeaconSlashingConfigs()._slashAmount,
      "[SlashIndicator] Invalid slash amount for random beacon"
    );
    assertEq(
      roninRandomBeacon.getActivatedAtPeriod(), REP10_ACTIVATION_PERIOD, "Invalid activated period for random beacon"
    );

    console.log("Submitting block reward at next block number...".yellow());
    TConsensus[] memory blockProducers = roninValidatorSet.getBlockProducers();
    uint256 currUnixTimestamp;
    TConsensus randomProducer = blockProducers[currUnixTimestamp % blockProducers.length];
    vm.coinbase(TConsensus.unwrap(randomProducer));
    vme.rollUpTo(vm.getBlockNumber() + 1);
    vm.prank(TConsensus.unwrap(randomProducer));
    roninValidatorSet.submitBlockReward{ value: 0.5 ether }();

    LibWrapUpEpoch.wrapUpEpoch();
    RoninMigration._postCheck();
  }
}

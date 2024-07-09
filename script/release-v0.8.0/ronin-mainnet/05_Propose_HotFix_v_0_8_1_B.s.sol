// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./REP10_Config_Mainnet_Base.s.sol";

contract Migration__05_Deploy_HotFix_FastFinalityTracking_Mainnet_Release_V0_8_1C is REP10_Config_Mainnet_Base {
  using LibProxy for *;
  using StdStyle for *;

  uint256 internal constant FAST_FINALITY_REWARD_PERCENTAGE = 8500;
  uint256 internal constant NEW_RANDOM_BEACON_UNAVAILABLE_SLASH_THRESHOLD = 7;

  Proposal.ProposalDetail internal _proposal;

  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    super.run();

    _targets = [address(fastFinalityTracking)];
    _values = [0];
    _callDatas =
      [abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (_deployLogic(Contract.FastFinalityTracking.key())))];

    for (uint256 i; i < _targets.length; ++i) {
      console.log("Target:", i, vm.toString(_targets[i]));
    }

    for (uint256 i; i < _callDatas.length; ++i) {
      console.log("CallData:", i, vm.toString(_callDatas[i]));
    }

    for (uint256 i; i < _values.length; ++i) {
      console.log("Value:", i, vm.toString(_values[i]));
    }
  }

  function _postCheck() internal virtual override {
    // Simulate Executing Proposal
    _proposal =
      LibProposal.buildProposal(roninGovernanceAdmin, vm.getBlockTimestamp() + 14 days, _targets, _values, _callDatas);
    LibProposal.executeProposal(roninGovernanceAdmin, roninTrustedOrganization, _proposal);

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

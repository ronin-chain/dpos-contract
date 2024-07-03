// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./REP10_Config_Mainnet_Base.s.sol";

contract Migration__04_ProposeProposal_Patch_REP10_Mainnet_v0_8_1_B is REP10_Config_Mainnet_Base {
  using StdStyle for *;

  uint256 internal constant FAST_FINALITY_REWARD_PERCENTAGE = 8500;
  uint256 internal constant NEW_RANDOM_BEACON_UNAVAILABLE_SLASH_THRESHOLD = 7;

  Proposal.ProposalDetail internal _proposal;

  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    super.run();

    roninRandomBeacon = IRandomBeacon(loadContract(Contract.RoninRandomBeacon.key()));
    // Verify: https://app.roninchain.com/address/0xC0D9f3ffFE76020F9C62f435672112b0895A4f3B
    roninValidatorSetREP10LogicMigrator = 0xC0D9f3ffFE76020F9C62f435672112b0895A4f3B;

    _targets = [
      0x617c5d73662282EA7FfD231E020eCa6D2B0D552f, // Verify address: https://app.roninchain.com/address/0x617c5d73662282EA7FfD231E020eCa6D2B0D552f
      0xC768423A2AE2B5024cB58F3d6449A8f5DB6D8816, // Verify address: https://app.roninchain.com/address/0xC768423A2AE2B5024cB58F3d6449A8f5DB6D8816
      0xaE4788294759C1ea2d095766Cc902786ba2280dc // Verify address: https://app.roninchain.com/address/0xaE4788294759C1ea2d095766Cc902786ba2280dc
    ];

    _callDatas = [
      bytes(hex"3659cfe6000000000000000000000000c0d9f3fffe76020f9c62f435672112b0895a4f3b"),
      bytes(
        hex"4f1ef286000000000000000000000000945aa80ed35897d2210c5d85fe204f439374935d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000446f5a2bc60000000000000000000000000000000000000000000000000000000000004dc4000000000000000000000000000000000000000000000000000000000000213400000000000000000000000000000000000000000000000000000000"
      ),
      bytes(
        hex"4bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243355b0f0000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000"
      )
    ];

    _values = [0, 0, 0];

    _proposal =
      LibProposal.buildProposal(roninGovernanceAdmin, vm.getBlockTimestamp() + 7 days, _targets, _values, _callDatas);

    vme.label(network(), BAKSON_WALLET, "Phuc Thai - Bakson");
    LibProposal.proposeProposal(roninGovernanceAdmin, roninTrustedOrganization, _proposal, BAKSON_WALLET);
  }

  function _postCheck() internal virtual override {
    LibProposal.voteProposalUntilExecute(roninGovernanceAdmin, roninTrustedOrganization, _proposal);

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./REP10_Config_Mainnet_Base.s.sol";

contract Migration__01_DeployREP10_Logics_Mainnet_Release_V0_8_0 is REP10_Config_Mainnet_Base {
  using LibProxy for *;
  using StdStyle for *;

  Proposal.ProposalDetail internal _proposal;

  function run() public virtual override onlyOn(DefaultNetwork.RoninMainnet.key()) {
    super.run();

    address payable[] memory allContracts = config.getAllAddresses(network());

    _deployAndInitializeRoninRandomBeacon();
    _deployRoninValidatorSetREP10MigratorLogic();

    _recordContractToUpgrade(address(roninGovernanceAdmin), allContracts); // Record contracts to upgrade

    (_targets, _values, _callDatas) = _buildProposalData();
    _updateProposalResetMaxValidatorCandidate();

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

    super._postCheck();
  }

  function _deployRoninValidatorSetREP10MigratorLogic() internal {
    roninValidatorSetREP10LogicMigrator =
      new RoninValidatorSetREP10MigratorLogicDeploy().overrideActivatedAtPeriod(REP10_ACTIVATION_PERIOD).run();
  }

  function _updateProposalResetMaxValidatorCandidate() internal {
    _targets.push(address(roninValidatorSet));
    _values.push(0);
    _callDatas.push(
      abi.encodeCall(
        TransparentUpgradeableProxyV2.functionDelegateCall,
        abi.encodeCall(ICandidateManager.setMaxValidatorCandidate, (NEW_MAX_VALIDATOR_CANDIDATE))
      )
    );
  }

  function _deployAndInitializeRoninRandomBeacon() internal {
    roninRandomBeacon = new RoninRandomBeaconDeploy().run();

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

    vm.startBroadcast(sender());

    roninRandomBeacon.initialize({
      profile: loadContract(Contract.Profile.key()),
      staking: loadContract(Contract.Staking.key()),
      trustedOrg: address(roninTrustedOrganization),
      validatorSet: loadContract(Contract.RoninValidatorSet.key()),
      slashThreshold: RANDOM_BEACON_SLASH_THRESHOLD,
      activatedAtPeriod: REP10_ACTIVATION_PERIOD,
      validatorTypes: validatorTypes,
      thresholds: thresholds
    });
    // To match with testnet
    roninRandomBeacon.initializeV2();
    roninRandomBeacon.initializeV3();

    vm.stopBroadcast();
  }

  function _buildProposalData()
    internal
    returns (address[] memory targets, uint256[] memory values, bytes[] memory callDatas)
  {
    uint256 innerCallCount = contractTypesToUpgrade.length;
    console.log("Number contract to upgrade:", innerCallCount);

    callDatas = new bytes[](innerCallCount);
    targets = new address[](innerCallCount);
    values = new uint256[](innerCallCount);
    address[] memory logics = new address[](innerCallCount);

    for (uint256 i; i < innerCallCount; ++i) {
      targets[i] = contractsToUpgrade[i];

      if (contractTypesToUpgrade[i] == Contract.RoninValidatorSet.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (
            roninValidatorSetREP10LogicMigrator,
            abi.encodeCall(RoninValidatorSetREP10Migrator.initialize, (address(roninRandomBeacon)))
          )
        );
      } else {
        logics[i] = _deployLogic(contractTypesToUpgrade[i]);
        callDatas[i] = abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logics[i]));
      }

      if (contractTypesToUpgrade[i] == Contract.FastFinalityTracking.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (logics[i], abi.encodeCall(IFastFinalityTracking.initializeV3, (loadContract(Contract.Staking.key()))))
        );
      }

      if (contractTypesToUpgrade[i] == Contract.SlashIndicator.key()) {
        callDatas[i] = abi.encodeCall(
          TransparentUpgradeableProxy.upgradeToAndCall,
          (
            logics[i],
            abi.encodeCall(
              ISlashIndicator.initializeV4,
              (address(roninRandomBeacon), SLASH_RANDOM_BEACON_AMOUNT, REP10_ACTIVATION_PERIOD)
            )
          )
        );
      }
    }
  }

  function _recordContractToUpgrade(address gov, address payable[] memory allContracts) internal {
    for (uint256 i; i < allContracts.length; i++) {
      address proxyAdmin = allContracts[i].getProxyAdmin(false);
      if (proxyAdmin != gov) {
        console.log(
          unicode"⚠ WARNING:".yellow(),
          string.concat(
            vm.getLabel(allContracts[i]),
            " has different ProxyAdmin. Expected: ",
            vm.getLabel(gov),
            " Got: ",
            vm.toString(proxyAdmin)
          )
        );

        continue;
      }

      address implementation = allContracts[i].getProxyImplementation();
      TContract contractType = config.getContractTypeFromCurrentNetwork(allContracts[i]);

      if (implementation.codehash != keccak256(vm.getDeployedCode(config.getContractAbsolutePath(contractType)))) {
        console.log(
          "Different Code Hash Detected. Contract To Upgrade:".cyan(),
          vm.getLabel(allContracts[i]),
          string.concat(" Query code Hash From: ", vm.getLabel(implementation))
        );

        contractTypesToUpgrade.push(contractType);
        contractsToUpgrade.push(allContracts[i]);

        continue;
      }

      console.log("Contract not to Upgrade:", vm.getLabel(allContracts[i]));
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
  IRoninTrustedOrganization,
  RoninTrustedOrganization
} from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { Proposal } from "@ronin/contracts/libraries/Proposal.sol";
import { Ballot } from "@ronin/contracts/libraries/Ballot.sol";
import { VoteStatusConsumer } from "@ronin/contracts/interfaces/consumers/VoteStatusConsumer.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { LibProxy } from "foundry-deployment-kit/libraries/LibProxy.sol";
import { LibErrorHandler } from "contract-libs/LibErrorHandler.sol";
import { TContract, TNetwork } from "foundry-deployment-kit/types/Types.sol";
import { Network } from "script/utils/Network.sol";
import { Contract } from "script/utils/Contract.sol";
import { GeneralConfig } from "./GeneralConfig.sol";
import { PostChecker } from "./PostChecker.sol";
import { DefaultNetwork } from "foundry-deployment-kit/utils/DefaultNetwork.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";

contract RoninMigration is PostChecker, VoteStatusConsumer {
  using StdStyle for *;
  using LibErrorHandler for bool;
  using LibProxy for address payable;

  ISharedArgument internal constant config = ISharedArgument(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(type(GeneralConfig).creationCode);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    RoninTrustedOrganization trustedOrg =
      RoninTrustedOrganization(config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key()));
    (uint256 num, uint256 denom) = trustedOrg.getThreshold();
    param.trustedOrgs = trustedOrg.getAllTrustedOrganizations();

    // ToDo(TuDo1403): should remove this cheat
    for (uint256 i; i < param.trustedOrgs.length; ++i) {
      // param.trustedOrgs[i].bridgeVoter = address(ripemd160(abi.encode(param.trustedOrgs[i].consensusAddr)));
    }
    param.num = num;
    param.denom = denom;
    param.expiryDuration = type(uint128).max;

    rawArgs = abi.encode(param);
  }

  function _deployProxy(TContract contractType) internal virtual override returns (address payable deployed) {
    string memory contractName = config.getContractName(contractType);
    bytes memory args = arguments();

    address logic = _deployLogic(contractType);
    string memory proxyAbsolutePath = "TransparentUpgradeableProxyV2.sol:TransparentUpgradeableProxyV2";
    uint256 proxyNonce;
    address proxyAdmin = _getProxyAdminFromCurrentNetwork();

    (deployed, proxyNonce) = _deployRaw(proxyAbsolutePath, abi.encode(logic, proxyAdmin, args));
    CONFIG.setAddress(network(), contractType, deployed);
    ARTIFACT_FACTORY.generateArtifact(
      sender(), deployed, proxyAbsolutePath, string.concat(contractName, "Proxy"), args, proxyNonce
    );
  }

  function _upgradeRaw(
    address proxyAdmin,
    address payable proxy,
    address logic,
    bytes memory args
  ) internal virtual override {
    assertTrue(proxyAdmin != address(0x0), "RoninMigration: Invalid {proxyAdmin} or {proxy} is not a Proxy contract");
    address governanceAdmin = _getProxyAdminFromCurrentNetwork();
    TNetwork currentNetwork = network();

    if (proxyAdmin == governanceAdmin) {
      // in case proxyAdmin is GovernanceAdmin
      if (
        currentNetwork == DefaultNetwork.RoninTestnet.key() ||
        currentNetwork == DefaultNetwork.RoninMainnet.key() ||
        currentNetwork == Network.RoninDevnet.key()
      ) {
        // handle for ronin network
        console.log(StdStyle.yellow("Voting on RoninGovernanceAdmin for upgrading..."));

        RoninGovernanceAdmin roninGovernanceAdmin = RoninGovernanceAdmin(governanceAdmin);
        bytes[] memory callDatas = new bytes[](1);
        uint256[] memory values = new uint256[](1);
        address[] memory targets = new address[](1);

        targets[0] = proxy;
        callDatas[0] = args.length == 0
          ? abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logic))
          : abi.encodeCall(TransparentUpgradeableProxy.upgradeToAndCall, (logic, args));

        Proposal.ProposalDetail memory proposal = _buildProposal({
          governanceAdmin: roninGovernanceAdmin,
          expiry: block.timestamp + 5 minutes,
          targets: targets,
          values: values,
          callDatas: callDatas
        });

        _executeProposal(
          roninGovernanceAdmin,
          RoninTrustedOrganization(config.getAddressFromCurrentNetwork(Contract.RoninTrustedOrganization.key())),
          proposal
        );

        assertEq(proxy.getProxyImplementation(), logic, "RoninMigration: Upgrade failed");
      } else if (currentNetwork == Network.Goerli.key() || currentNetwork == Network.EthMainnet.key()) {
        // handle for ethereum
        revert("RoninMigration: Unhandled case for ETH");
      } else {
        revert("RoninMigration: Unhandled case");
      }
    } else if (proxyAdmin.code.length == 0) {
      // in case proxyAdmin is an eoa
      console.log(StdStyle.yellow("Upgrading with EOA wallet..."));
      vm.broadcast(address(proxyAdmin));
      if (args.length == 0) TransparentUpgradeableProxyV2(proxy).upgradeTo(logic);
      else TransparentUpgradeableProxyV2(proxy).upgradeToAndCall(logic, args);
    } else {
      console.log(StdStyle.yellow("Upgrading with owner of ProxyAdmin contract..."));
      // in case proxyAdmin is a ProxyAdmin contract
      ProxyAdmin proxyAdminContract = ProxyAdmin(proxyAdmin);
      address authorizedWallet = proxyAdminContract.owner();
      vm.broadcast(authorizedWallet);
      if (args.length == 0) proxyAdminContract.upgrade(TransparentUpgradeableProxy(proxy), logic);
      else proxyAdminContract.upgradeAndCall(TransparentUpgradeableProxy(proxy), logic, args);
    }
  }

  function _getProxyAdminFromCurrentNetwork() internal view virtual returns (address proxyAdmin) {
    TNetwork currentNetwork = network();
    if (currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == DefaultNetwork.RoninMainnet.key()) {
      proxyAdmin = config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key());
    } else if (currentNetwork == Network.Goerli.key() || currentNetwork == Network.EthMainnet.key()) {
      proxyAdmin = config.getAddressFromCurrentNetwork(Contract.MainchainBridgeManager.key());
    }
  }

  function _executeProposal(
    RoninGovernanceAdmin governanceAdmin,
    RoninTrustedOrganization roninTrustedOrg,
    Proposal.ProposalDetail memory proposal
  ) internal override {
    Ballot.VoteType support = Ballot.VoteType.For;
    IRoninTrustedOrganization.TrustedOrganization[] memory allTrustedOrgs = roninTrustedOrg.getAllTrustedOrganizations();

    bool shouldPrankOnly = CONFIG.isBroadcastDisable();
    address trustedOrg0 = allTrustedOrgs[0].governor;

    if (shouldPrankOnly) {
      vm.prank(trustedOrg0);
    } else {
      vm.broadcast(trustedOrg0);
    }
    governanceAdmin.proposeProposalForCurrentNetwork(
      proposal.expiryTimestamp, proposal.targets, proposal.values, proposal.calldatas, proposal.gasAmounts, support
    );

    for (uint256 i = 1; i < allTrustedOrgs.length; ++i) {
      (VoteStatus status,,,,) = governanceAdmin.vote(block.chainid, proposal.nonce);
      if (status != VoteStatus.Pending) {
        break;
      }

      address iTrustedOrg = allTrustedOrgs[i].governor;
      if (shouldPrankOnly) {
        vm.prank(iTrustedOrg);
      } else {
        vm.broadcast(iTrustedOrg);
      }
      governanceAdmin.castProposalVoteForCurrentNetwork(proposal, support);
    }
  }

  function _buildProposal(
    RoninGovernanceAdmin governanceAdmin,
    uint256 expiry,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory callDatas
  ) internal override returns (Proposal.ProposalDetail memory proposal) {
    require(targets.length == values.length && values.length == callDatas.length, "RoninMigration: Length mismatch");

    uint256[] memory gasAmounts = new uint256[](targets.length);
    uint256 snapshotId = vm.snapshot();

    vm.startPrank(address(governanceAdmin));

    uint DEFAULT_PROPOSAL_GAS = 1_000_000;
    for (uint256 i; i < targets.length; ++i) {
      vm.deal(address(governanceAdmin), values[0]);
      uint256 gas = gasleft();
      (bool success, bytes memory returnOrRevertData) = targets[i].call{ value: values[0] }(callDatas[i]);
      gas -= gasleft();
      success.handleRevert(msg.sig, returnOrRevertData);
      // add 50% extra gas amount
      gasAmounts[i] = gas < DEFAULT_PROPOSAL_GAS / 2 ? DEFAULT_PROPOSAL_GAS : (gas * 150_00) / 100_00;
    }

    vm.stopPrank();

    proposal = Proposal.ProposalDetail(
      governanceAdmin.round(block.chainid) + 1, block.chainid, expiry, targets, values, callDatas, gasAmounts
    );

    vm.revertTo(snapshotId);
    _logProposal(address(governanceAdmin), proposal);
  }

  function _logProposal(address governanceAdmin, Proposal.ProposalDetail memory proposal) internal {
    console.log(
      string.concat(
        StdStyle.magenta(
          string.concat(
            "\n================================================================================= ",
            "Proposal Detail",
            " =================================================================================\n"
          )
        ),
        "GovernanceAdmin: ",
        vm.getLabel(governanceAdmin),
        "\tNonce: ",
        vm.toString(proposal.nonce)
      )
    );

    string[] memory commandInput = new string[](3);
    commandInput[0] = "cast";
    commandInput[1] = "4byte-decode";

    bytes[] memory decodedCallDatas = new bytes[](proposal.targets.length);
    for (uint256 i; i < proposal.targets.length; ++i) {
      commandInput[2] = vm.toString(proposal.calldatas[i]);
      decodedCallDatas[i] = vm.ffi(commandInput);
    }

    for (uint256 i; i < proposal.targets.length; ++i) {
      console.log(
        string.concat(
          StdStyle.blue(
            string.concat(
              "\n==================================================================== ",
              "Index: ",
              vm.toString(i),
              " ====================================================================\n"
            )
          ),
          "Target:\t",
          vm.getLabel(proposal.targets[i]),
          "\t|| Value:\t",
          vm.toString(proposal.values[i]),
          "\t|| Gas amount:\t",
          vm.toString(proposal.gasAmounts[i]),
          "\nCalldata:\n",
          string(decodedCallDatas[i]).yellow()
        )
      );
    }

    console.log(
      StdStyle.magenta(
        string.concat(
          "\n=======================================================================",
          "=========================================================================",
          "===================================\n"
        )
      )
    );
  }
}

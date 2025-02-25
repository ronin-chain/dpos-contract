// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IPostCheck } from "./interfaces/IPostCheck.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { BaseMigration } from "@fdk/BaseMigration.s.sol";

import { DeployInfo, LibDeploy, ProxyInterface, UpgradeInfo } from "@fdk/libraries/LibDeploy.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { TContract, TNetwork } from "@fdk/types/Types.sol";
import { vme } from "@fdk/utils/Constants.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { ProxyAdmin } from "@openzeppelin-v4/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from
  "@openzeppelin-v4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LibString } from "@solady/utils/LibString.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";

import { LibApplyCandidate } from "script/shared/libraries/LibApplyCandidate.sol";
import { LibProposal } from "script/shared/libraries/LibProposal.sol";
import { LibWrapUpEpoch } from "script/shared/libraries/LibWrapUpEpoch.sol";
import { Contract } from "script/utils/Contract.sol";
import { Network } from "script/utils/Network.sol";
import { IRoninGovernanceAdmin } from "src/interfaces/IRoninGovernanceAdmin.sol";
import { IRoninTrustedOrganization } from "src/interfaces/IRoninTrustedOrganization.sol";
import { IRandomBeacon } from "src/interfaces/random-beacon/IRandomBeacon.sol";
import { Proposal } from "src/libraries/Proposal.sol";
import { TConsensus } from "src/udvts/Types.sol";

contract RoninMigration is BaseMigration {
  using LibProxy for *;
  using LibString for bytes32;

  ISharedArgument internal constant config = ISharedArgument(address(vme));
  uint256 internal constant OFFSET_TO_ACTIVATE = 3;
  uint256 internal REP10_ACTIVATED_PERIOD = (vm.unixTime() / 1000) / 1 days + OFFSET_TO_ACTIVATE;

  string internal constant DEFAULT_CONFIG_PATH = "script/config/config.";
  string internal _configPath;

  constructor() BaseMigration() {
    _saveSysContracts(address(this));
  }

  function _saveSysContracts(
    address addr
  ) internal {
    address[] memory sysContracts;
    try vme.getUserDefinedConfig("system-contracts") returns (bytes memory ret) {
      if (ret.length != 0) sysContracts = abi.decode(ret, (address[]));
    } catch { }

    address[] memory newSysContracts = new address[](sysContracts.length + 1);
    for (uint256 i = 0; i < sysContracts.length; i++) {
      newSysContracts[i] = sysContracts[i];
    }
    newSysContracts[sysContracts.length] = addr;

    vme.setUserDefinedConfig("system-contracts", abi.encode(newSysContracts));
  }

  function _configByteCode() internal virtual override returns (bytes memory) {
    return vm.getCode("out/GeneralConfig.sol/GeneralConfig.json");
  }

  function _postCheck() internal virtual override {
    address postChecker = _deployImmutable(Contract.PostChecker.key());
    vm.allowCheatcodes(postChecker);
    IPostCheck(postChecker).run();
    _saveSysContracts(postChecker);
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    param = _parseConfig(string.concat(DEFAULT_CONFIG_PATH));

    rawArgs = abi.encode(param);
  }

  function _parseConfig(
    string memory configPath
  ) internal virtual returns (ISharedArgument.SharedParameter memory) {
    string memory chainAlias = vme.getNetworkData(network()).chainAlias;
    _configPath = string.concat(configPath, chainAlias, ".json");

    bytes memory ret = vme.getUserDefinedConfig("config-loaded-network");
    if (ret.length != 0 && keccak256(ret) == keccak256(bytes(chainAlias))) return config.sharedArguments();

    if (vm.exists(_configPath)) {
      string memory json = vm.readFile(_configPath);
      vme.setUserDefinedConfig("config-loaded-network", bytes(chainAlias));
      return abi.decode(vm.parseJson(json), (ISharedArgument.SharedParameter));
    } else {
      console.log("Config not found at path: ", _configPath);
    }
  }

  function parseTrustedOrganizations(
    ISharedArgument.TrustedOrganization[] memory data
  ) internal pure returns (IRoninTrustedOrganization.TrustedOrganization[] memory ret) {
    ret = new IRoninTrustedOrganization.TrustedOrganization[](data.length);
    for (uint256 i; i < data.length; ++i) {
      ret[i].__deprecatedBridgeVoter = data[i].__deprecatedBridgeVoter;
      ret[i].addedBlock = data[i].addedBlock;
      ret[i].consensusAddr = TConsensus.wrap(data[i].consensusAddr);
      ret[i].governor = data[i].governor;
      ret[i].weight = data[i].weight;
    }
  }

  function _deployProxy(
    TContract contractType
  )
    internal
    virtual
    override
    logFn(string.concat("_deployProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable deployed)
  {
    string memory contractName = vme.getContractName(contractType);
    bytes memory callData = arguments();

    address proxyAdmin = _getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "BaseMigration: Null ProxyAdmin");

    deployed = LibDeploy.deployTransparentProxy({
      implInfo: DeployInfo({
        callValue: 0,
        by: sender(),
        contractName: contractName,
        absolutePath: vme.getContractAbsolutePath(contractType),
        artifactName: contractName,
        constructorArgs: ""
      }),
      callValue: 0,
      proxyAdmin: _getProxyAdmin(),
      callData: callData
    });

    // validate proxy admin
    address actualProxyAdmin = deployed.getProxyAdmin();
    assertEq(
      actualProxyAdmin,
      proxyAdmin,
      string.concat(
        "BaseMigration: Invalid proxy admin\n",
        "Actual: ",
        vm.toString(actualProxyAdmin),
        "\nExpected: ",
        vm.toString(proxyAdmin)
      )
    );

    vme.setAddress(network(), contractType, deployed);
  }

  function _upgradeProxy(
    TContract contractType,
    bytes memory args,
    bytes memory argsLogicConstructor
  )
    internal
    virtual
    override
    logFn(string.concat("_upgradeProxy ", TContract.unwrap(contractType).unpackOne()))
    returns (address payable proxy)
  {
    proxy = loadContract(contractType);
    address logic = _deployLogic(contractType, argsLogicConstructor);

    UpgradeInfo({
      proxy: proxy,
      logic: logic,
      callValue: 0,
      callData: args,
      proxyInterface: ProxyInterface.Transparent,
      shouldPrompt: false,
      upgradeCallback: _upgradeCallback,
      shouldUseCallback: true
    }).upgrade();
  }

  function _upgradeCallback(
    address proxy,
    address logic,
    uint256, /* callValue */
    bytes memory callData,
    ProxyInterface /* proxyInterface */
  ) internal virtual override {
    address proxyAdmin = proxy.getProxyAdmin();
    assertTrue(proxyAdmin != address(0x0), "RoninMigration: Invalid {proxyAdmin} or {proxy} is not a Proxy contract");
    address governanceAdmin = _getProxyAdminFromCurrentNetwork();
    TNetwork currentNetwork = network();

    if (proxyAdmin == governanceAdmin) {
      // in case proxyAdmin is GovernanceAdmin
      if (
        currentNetwork == DefaultNetwork.RoninTestnet.key() || currentNetwork == DefaultNetwork.RoninMainnet.key()
          || currentNetwork == Network.RoninDevnet.key() || currentNetwork == DefaultNetwork.LocalHost.key()
          || currentNetwork == Network.ShadowForkMainnet.key() || currentNetwork == Network.ShadowForkTestnet.key()
      ) {
        // handle for ronin network
        console.log(StdStyle.yellow("Voting on RoninGovernanceAdmin for upgrading..."));

        IRoninGovernanceAdmin roninGovernanceAdmin = IRoninGovernanceAdmin(governanceAdmin);
        bytes[] memory callDatas = new bytes[](1);
        uint256[] memory values = new uint256[](1);
        address[] memory targets = new address[](1);

        targets[0] = proxy;
        callDatas[0] = callData.length == 0
          ? abi.encodeCall(TransparentUpgradeableProxy.upgradeTo, (logic))
          : abi.encodeCall(TransparentUpgradeableProxy.upgradeToAndCall, (logic, callData));

        Proposal.ProposalDetail memory proposal = LibProposal.buildProposal({
          governanceAdmin: roninGovernanceAdmin,
          expiry: vm.getBlockTimestamp() + 1 hours,
          targets: targets,
          values: values,
          callDatas: callDatas
        });

        LibProposal.executeProposal(
          roninGovernanceAdmin,
          IRoninTrustedOrganization(loadContract(Contract.RoninTrustedOrganization.key())),
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
      if (callData.length == 0) TransparentUpgradeableProxy(payable(proxy)).upgradeTo(logic);
      else TransparentUpgradeableProxy(payable(proxy)).upgradeToAndCall(logic, callData);
    } else {
      console.log(StdStyle.yellow("Upgrading with owner of ProxyAdmin contract..."));
      // in case proxyAdmin is a ProxyAdmin contract
      ProxyAdmin proxyAdminContract = ProxyAdmin(proxyAdmin);
      address authorizedWallet = proxyAdminContract.owner();
      vm.broadcast(authorizedWallet);
      if (callData.length == 0) proxyAdminContract.upgrade(TransparentUpgradeableProxy(payable(proxy)), logic);
      else proxyAdminContract.upgradeAndCall(TransparentUpgradeableProxy(payable(proxy)), logic, callData);
    }
  }

  function _getProxyAdmin() internal view virtual override returns (address payable) {
    return payable(_getProxyAdminFromCurrentNetwork());
  }

  function _getProxyAdminFromCurrentNetwork() internal view virtual returns (address proxyAdmin) {
    if (network() == DefaultNetwork.LocalHost.key()) {
      address deployedProxyAdmin;
      try config.getAddressFromCurrentNetwork(Contract.RoninGovernanceAdmin.key()) returns (address payable res) {
        deployedProxyAdmin = res;
      } catch { }

      return deployedProxyAdmin == address(0x0) ? sender() : deployedProxyAdmin;
    }

    return loadContract(Contract.RoninGovernanceAdmin.key());
  }
}

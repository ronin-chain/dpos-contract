// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { VRF } from "@chainlink/contracts/src/v0.8/VRF.sol";
import { Vm, VmSafe } from "forge-std/Vm.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";
import { Contract } from "script/utils/Contract.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { JSONParserLib } from "@solady/utils/JSONParserLib.sol";
import { RandomRequest } from "@ronin/contracts/libraries/LibSLA.sol";
import { IRandomBeacon } from "@ronin/contracts/interfaces/random-beacon/IRandomBeacon.sol";

library LibVRFProof {
  using LibString for *;
  using JSONParserLib for *;

  struct VRFKey {
    bytes32 keyHash;
    bytes32 secretKey;
    uint256 privateKey;
    address oracle;
  }

  event RoninRandomBeaconNotYetDeployed();

  Vm internal constant vm = Vm(LibSharedAddress.VM);
  string internal constant CONFIG_PATH = "config/";
  IGeneralConfig internal constant config = IGeneralConfig(LibSharedAddress.VME);

  function listenEventAndSubmitProof() internal {
    LibVRFProof.VRFKey[] memory keys = abi.decode(config.getUserDefinedConfig("vrf-keys"), (LibVRFProof.VRFKey[]));
    listenEventAndSubmitProof(keys);
  }

  function listenEventAndSubmitProof(VRFKey[] memory keys) internal {
    if (keys.length == 0) return;

    VmSafe.Log[] memory logs = vm.getRecordedLogs();

    address randomBeacon;
    try config.getAddressFromCurrentNetwork(Contract.RoninRandomBeacon.key()) returns (address payable addr) {
      randomBeacon = addr;
    } catch {
      emit RoninRandomBeaconNotYetDeployed();
      return;
    }

    (bytes32 keyHash, RandomRequest memory req) = LibVRFProof.parseRequest(logs, randomBeacon);
    if (keyHash == 0x0) return;

    for (uint256 i; i < keys.length; ++i) {
      LibVRFProof.VRFKey memory key = keys[i];
      VRF.Proof memory proof = LibVRFProof.genProof(key, randomBeacon, req);
      vm.prank(key.oracle);
      IRandomBeacon(randomBeacon).fulfillRandomSeed(req, proof);
    }
  }

  function genVRFKeys(uint256 count) internal returns (VRFKey[] memory keys) {
    string[] memory cmdInput = new string[](1);
    cmdInput[0] = "./script/misc/genkey.sh";
    keys = new VRFKey[](count);

    for (uint256 i; i < count; ++i) {
      string memory raw = string(vm.ffi(cmdInput));
      string[] memory s = raw.split(",");

      keys[i].keyHash = vm.parseBytes32(s[1]);
      keys[i].secretKey = vm.parseBytes32(s[2]);
      (keys[i].oracle, keys[i].privateKey) = makeAddrAndKey(string.concat("oracle-", vm.toString(i)));

      console.log("keyHash", i, vm.toString(keys[i].keyHash));
      console.log("secretKey", i, vm.toString(keys[i].secretKey));
      console.log("oracle", i, keys[i].oracle);
      console.log("privateKey", i, vm.toString(keys[i].privateKey));
    }
  }

  function genProof(
    VRFKey memory key,
    address randomBeacon,
    RandomRequest memory req
  ) internal returns (VRF.Proof memory proof) {
    string memory configFileName = string.concat(CONFIG_PATH, "config");
    vm.copyFile("config/config.example.json", string.concat(configFileName, ".json"));

    vm.writeJson(vm.toString(block.chainid), string.concat(configFileName, ".json"), ".chainId");
    vm.writeJson(vm.toString(key.secretKey), string.concat(configFileName, ".json"), ".secret_key");
    vm.writeJson(vm.toString(key.oracle), string.concat(configFileName, ".json"), ".oracle_address");
    vm.writeJson(vm.toString(bytes32(key.privateKey)), string.concat(configFileName, ".json"), ".private_key");
    vm.writeJson(vm.toString(randomBeacon), string.concat(configFileName, ".json"), ".coordinator_address");

    string[] memory cmdInput = new string[](2);
    cmdInput[0] = "./script/misc/json2yaml.sh";
    cmdInput[1] = "config";

    vm.ffi(cmdInput);

    string memory outDir = string.concat("script/data/cache", "/", vm.toString(msg.sig));
    if (!vm.exists(outDir)) vm.createDir(outDir, false);

    cmdInput = new string[](7);

    cmdInput[0] = "./ronin-random-beacon";
    cmdInput[1] = "random";
    cmdInput[2] = "--config-file";
    cmdInput[3] = CONFIG_PATH;
    cmdInput[4] = string.concat("--period=", vm.toString(req.period));
    cmdInput[5] = string.concat("--prev-beacon=", vm.toString(req.prevBeacon));
    cmdInput[6] = string.concat("--output-path=", outDir);

    string memory command;
    for (uint256 i; i < cmdInput.length; ++i) {
      command = string.concat(command, " ", cmdInput[i]);
    }

    vm.tryFfi(cmdInput);
    proof = parseProof(string.concat(outDir, "/random-result.json"));
  }

  function parseRequest(
    VmSafe.Log[] memory logs,
    address emitter
  ) internal pure returns (bytes32 reqHash, RandomRequest memory req) {
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].emitter == emitter && logs[i].topics[0] == IRandomBeacon.RandomSeedRequested.selector) {
        reqHash = logs[i].topics[2];
        req = abi.decode(logs[i].data, (RandomRequest));
      }
    }
  }

  function parseProof(string memory proofPath) internal view returns (VRF.Proof memory proof) {
    string memory raw = vm.readFile(proofPath);
    JSONParserLib.Item memory data = raw.parse();

    proof.pk[0] = vm.parseUint(data.at('"pk"').at(0).value().decodeString());
    proof.pk[1] = vm.parseUint(data.at('"pk"').at(1).value().decodeString());

    proof.gamma[0] = vm.parseUint(data.at('"gamma"').at(0).value().decodeString());
    proof.gamma[1] = vm.parseUint(data.at('"gamma"').at(1).value().decodeString());

    proof.c = vm.parseUint(data.at('"c"').value().decodeString());
    proof.s = vm.parseUint(data.at('"s"').value().decodeString());
    proof.seed = vm.parseUint(data.at('"seed"').value().decodeString());
    proof.uWitness = vm.parseAddress(data.at('"uWitness"').value().decodeString());

    proof.cGammaWitness[0] = vm.parseUint(data.at('"cGammaWitness"').at(0).value().decodeString());
    proof.cGammaWitness[1] = vm.parseUint(data.at('"cGammaWitness"').at(1).value().decodeString());

    proof.sHashWitness[0] = vm.parseUint(data.at('"sHashWitness"').at(0).value().decodeString());
    proof.sHashWitness[1] = vm.parseUint(data.at('"sHashWitness"').at(1).value().decodeString());

    proof.zInv = vm.parseUint(data.at('"zInv"').value().decodeString());
  }

  function logProof(VRF.Proof memory proof) internal view {
    console.log("\n==================================================================================");

    console.log("pk[0]", proof.pk[0]);
    console.log("pk[1]", proof.pk[1]);

    console.log("gamma[0]", proof.gamma[0]);
    console.log("gamma[1]", proof.gamma[1]);

    console.log("c", proof.c);
    console.log("s", proof.s);
    console.log("seed", proof.seed);
    console.log("uWitness", proof.uWitness);

    console.log("cGammaWitness[0]", proof.cGammaWitness[0]);
    console.log("cGammaWitness[1]", proof.cGammaWitness[1]);

    console.log("sHashWitness[0]", proof.sHashWitness[0]);
    console.log("sHashWitness[1]", proof.sHashWitness[1]);

    console.log("zInv", proof.zInv);

    console.log("====================================================================================\n");
  }

  function makeAddrAndKey(string memory name) private returns (address addr, uint256 privateKey) {
    privateKey = uint256(keccak256(abi.encodePacked(name)));
    addr = vm.addr(privateKey);
    vm.label(addr, name);
  }
}

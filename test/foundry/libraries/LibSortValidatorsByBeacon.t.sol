// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { Test } from "forge-std/Test.sol";
import { LibSortValidatorsByBeacon } from "@ronin/contracts/libraries/LibSortValidatorsByBeacon.sol";
import { LibSortValidatorsByBeaconOld } from "./mocks/LibSortValidatorsByBeaconOld.sol";
import { LibArray } from "@ronin/contracts/libraries/LibArray.sol";

contract LibSortValidatorsByBeaconTest is Test {
  using StdStyle for *;

  uint256 constant threshold = 64;
  uint256 constant maxValidator = 22;

  /// @dev The minimum epoch value.
  uint256 internal constant MIN_EPOCH = 1;
  /// @dev The maximum epoch value.
  uint256 internal constant MAX_EPOCH = 144;

  uint96[] stakeAmounts = [
    uint96(1450000 ether),
    uint96(690000 ether),
    uint96(830990 ether),
    uint96(470000 ether),
    uint96(550000 ether),
    uint96(450000 ether),
    uint96(599999 ether),
    uint96(500000 ether),
    uint96(500000 ether),
    uint96(790000 ether),
    uint96(500000 ether),
    uint96(500000 ether),
    uint96(1450000 ether),
    uint96(1450000 ether),
    uint96(790000 ether),
    uint96(500000 ether),
    uint96(500000 ether),
    uint96(500000 ether)
  ];
  address[] idValues = [
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x0", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x1", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x2", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x3", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x4", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x5", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x6", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x7", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x8", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x9", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0xa", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0xb", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0xc", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0xd", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0xe", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x10", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x11", vm.unixTime()))))),
    address(vm.addr(uint256(keccak256(abi.encodePacked("0x12", vm.unixTime())))))
  ];
  uint256 numRv = 7;

  mapping(address => uint256 count) pickCount;
  mapping(address => uint256 index) indexOf;

  function testConcrete_randomDistribution() external {
    LibSortValidatorsByBeacon.RotatingValidatorStorage[] memory packedRVs =
      new LibSortValidatorsByBeacon.RotatingValidatorStorage[](idValues.length);
    require(idValues.length == stakeAmounts.length, "length mismatch");

    for (uint256 i; i < idValues.length; i++) {
      packedRVs[i]._cid = idValues[i];
      packedRVs[i]._staked = stakeAmounts[i];
    }

    uint256 numSamples = 144;
    uint256[] memory beaconValues = random(numSamples, uint256(keccak256("beaconValues")));
    beaconValues[0] = 0;
    uint256[] memory epochValues = random(numSamples, uint256(keccak256("epochValues")));

    for (uint256 i; i < numSamples; ++i) {
      address[] memory cids =
        LibSortValidatorsByBeacon.pickTopKRotatingValidatorsByBeaconWeight(packedRVs, numRv, 0, epochValues[0] + i);

      assertEq(cids.length, numRv, "Invalid number of picked weights");

      for (uint256 j; j < cids.length; ++j) {
        pickCount[cids[j]]++;
      }
    }

    for (uint256 i; i < packedRVs.length; ++i) {
      address cid = packedRVs[i]._cid;
      uint256 staked = packedRVs[i]._staked;
      string memory log = string.concat(
        "CID: ".yellow(),
        vm.toString(cid),
        " Staked: ",
        vm.toString(staked / 1 ether),
        " RON".blue(),
        " Pick Count: ",
        vm.toString(pickCount[cid]),
        " Pick Rate ".yellow(),
        vm.toString(pickCount[cid] * 100 / numSamples),
        "%"
      );
      console.log(log);
    }
  }

  function random(uint256 numSample, uint256 v) private returns (uint256[] memory r) {
    r = new uint256[](numSample);
    for (uint256 i = 0; i < numSample; i++) {
      r[i] = uint256(keccak256(abi.encode(i, v, vm.unixTime())));
    }
  }

  function testConcrete_sortValidatorsByBeaconOld() external {
    uint256 numGovernanceValidator = 2;
    uint256 numStandardValidator = 2;
    uint256 numRotatingValidator = 1;

    address[] memory ids = new address[](6);
    ids[0] = address(1);
    ids[1] = address(2);
    ids[2] = address(3);
    ids[3] = address(4);
    ids[4] = address(5);
    ids[5] = address(6);

    uint256[] memory stakedAmounts = new uint256[](6);
    stakedAmounts[0] = uint96(10 ether);
    stakedAmounts[1] = uint96(20 ether);
    stakedAmounts[2] = uint96(30 ether);
    stakedAmounts[3] = uint96(40 ether);
    stakedAmounts[4] = uint96(50 ether);
    stakedAmounts[5] = uint96(60 ether);

    uint256[] memory trustedWeights = new uint256[](6);
    trustedWeights[0] = 1;
    trustedWeights[1] = 1;
    trustedWeights[2] = 0;
    trustedWeights[3] = 0;
    trustedWeights[4] = 0;
    trustedWeights[5] = 0;

    vm.record();
    LibSortValidatorsByBeaconOld.filterAndSaveValidators(
      1, 1, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    for (uint256 i = MIN_EPOCH; i <= MAX_EPOCH; i++) {
      address[] memory picked = LibSortValidatorsByBeaconOld.pickValidatorSet(1, i);
      uint256 numNonRotatingValidator = picked.length - 1;
      assertEq(numNonRotatingValidator, 4, "Invalid number of non-rotating validators");
      // Non-rotating: address: 1, 2, 6, 5
      assertEq(picked[0], address(1), "Invalid non-rotating validator");
      assertEq(picked[1], address(2), "Invalid non-rotating validator");
      assertEq(picked[2], address(6), "Invalid non-rotating validator");
      assertEq(picked[3], address(5), "Invalid non-rotating validator");

      console.log(string.concat("epoch: ", vm.toString(i), ","), "address:", picked[picked.length - 1]);
    }
  }

  function testConcrete_shouldReplaceHoldSet_whenRequestAgain(uint256 r) external {
    uint256 numGovernanceValidator = 2;
    uint256 numStandardValidator = 2;
    uint256 numRotatingValidator = 1;

    address[] memory ids = new address[](6);
    ids[0] = address(1);
    ids[1] = address(2);
    ids[2] = address(3);
    ids[3] = address(4);
    ids[4] = address(5);
    ids[5] = address(6);

    uint256[] memory stakedAmounts = new uint256[](6);
    stakedAmounts[0] = uint96(10 ether);
    stakedAmounts[1] = uint96(20 ether);
    stakedAmounts[2] = uint96(30 ether);
    stakedAmounts[3] = uint96(40 ether);
    stakedAmounts[4] = uint96(50 ether);
    stakedAmounts[5] = uint96(60 ether);

    uint256[] memory trustedWeights = new uint256[](6);
    trustedWeights[0] = 1;
    trustedWeights[1] = 1;
    trustedWeights[2] = 0;
    trustedWeights[3] = 0;
    trustedWeights[4] = 0;
    trustedWeights[5] = 0;

    LibSortValidatorsByBeacon.filterAndSaveValidators(
      1, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );

    address[] memory newIds = new address[](6);
    newIds[0] = address(10);
    newIds[1] = address(20);
    newIds[2] = address(30);
    newIds[3] = address(40);
    newIds[4] = address(50);
    newIds[5] = address(60);

    trustedWeights[0] = 10;
    trustedWeights[1] = 10;
    trustedWeights[2] = 0;
    trustedWeights[3] = 0;
    trustedWeights[4] = 0;
    trustedWeights[5] = 0;

    stakedAmounts[0] = uint96(100 ether);
    stakedAmounts[1] = uint96(200 ether);
    stakedAmounts[2] = uint96(300 ether);
    stakedAmounts[3] = uint96(400 ether);
    stakedAmounts[4] = uint96(500 ether);
    stakedAmounts[5] = uint96(600 ether);

    LibSortValidatorsByBeacon.filterAndSaveValidators(
      1, numGovernanceValidator, numStandardValidator, numRotatingValidator, newIds, stakedAmounts, trustedWeights
    );

    r = _bound(r, MIN_EPOCH, MAX_EPOCH);

    bool duplicated;
    address[] memory pickeds = LibSortValidatorsByBeacon.pickValidatorSet(1, r, 1);
    for (uint256 i; i < pickeds.length; i++) {
      for (uint256 j; j < ids.length; j++) {
        if (pickeds[i] == ids[j]) {
          duplicated = true;
          console.log("Duplicated address:", pickeds[i]);
          break;
        }
      }
    }

    assertFalse(duplicated, "Should replace hold set");
  }

  function testConcrete_sortValidatorsByBeacon() external {
    uint256 beacon = uint256(keccak256("aaa"));
    uint256 numGovernanceValidator = 2;
    uint256 numStandardValidator = 2;
    uint256 numRotatingValidator = 1;

    address[] memory ids = new address[](6);
    ids[0] = address(1);
    ids[1] = address(2);
    ids[2] = address(3);
    ids[3] = address(4);
    ids[4] = address(5);
    ids[5] = address(6);

    uint256[] memory stakedAmounts = new uint256[](6);
    stakedAmounts[0] = uint96(10 ether);
    stakedAmounts[1] = uint96(20 ether);
    stakedAmounts[2] = uint96(30 ether);
    stakedAmounts[3] = uint96(40 ether);
    stakedAmounts[4] = uint96(50 ether);
    stakedAmounts[5] = uint96(60 ether);

    uint256[] memory trustedWeights = new uint256[](6);
    trustedWeights[0] = 1;
    trustedWeights[1] = 1;
    trustedWeights[2] = 0;
    trustedWeights[3] = 0;
    trustedWeights[4] = 0;
    trustedWeights[5] = 0;

    vm.record();
    LibSortValidatorsByBeacon.filterAndSaveValidators(
      1, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    for (uint256 i = MIN_EPOCH; i <= MAX_EPOCH; i++) {
      address[] memory picked = LibSortValidatorsByBeacon.pickValidatorSet(1, i, beacon);
      uint256 numNonRotatingValidator = picked.length - 1;
      assertEq(numNonRotatingValidator, 4, "Invalid number of non-rotating validators");
      // Non-rotating: address: 1, 2, 6, 5
      assertEq(picked[0], address(1), "Invalid non-rotating validator");
      assertEq(picked[1], address(2), "Invalid non-rotating validator");
      assertEq(picked[2], address(6), "Invalid non-rotating validator");
      assertEq(picked[3], address(5), "Invalid non-rotating validator");

      console.log(string.concat("epoch: ", vm.toString(i), ","), "address:", picked[picked.length - 1]);
    }
  }

  function testConcreteGas_ZeroRV_sortValidatorsByBeaconOld() public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    uint256 numStandardValidator = 10;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;
    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked("validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked("staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked("trusted-weight", i))) % 100 + 1;
      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    require(c == numGovernanceValidator, "Invalid number of governance validators");

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeaconOld.filterAndSaveValidators(
      1, 1, numGovernanceValidator, numStandardValidator, 0, ids, stakedAmounts, trustedWeights
    );
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);
    vm.resumeGasMetering();
  }

  function testConcreteGas_ZeroSV_sortValidatorsByBeaconOld() public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    uint256 numRotatingValidator = 10;

    uint256 numValidators = numGovernanceValidator + numRotatingValidator;
    console.log("Num validators:", numValidators);

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked("validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked("staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked("trusted-weight", i))) % 100 + 1;
      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    require(c == numGovernanceValidator, "Invalid number of governance validators");

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeaconOld.filterAndSaveValidators(
      1, 1, numGovernanceValidator, 0, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }

  function testConcreteGas_ZeroRV_sortValidatorsByBeacon() public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    uint256 numStandardValidator = 10;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;
    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked("validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked("staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked("trusted-weight", i))) % 100 + 1;
      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    require(c == numGovernanceValidator, "Invalid number of governance validators");

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeacon.filterAndSaveValidators(
      1, numGovernanceValidator, numStandardValidator, 0, ids, stakedAmounts, trustedWeights
    );
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }

  function testConcreteGas_ZeroSV_sortValidatorsByBeacon() public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    uint256 numRotatingValidator = 10;

    uint256 numValidators = numGovernanceValidator + numRotatingValidator;
    console.log("Num validators:", numValidators);

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked("validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked("staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked("trusted-weight", i))) % 100 + 1;
      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    require(c == numGovernanceValidator, "Invalid number of governance validators");

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeacon.filterAndSaveValidators(
      1, numGovernanceValidator, 0, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }

  function testFuzzGas_sortValidatorsByBeaconOld(uint256 r, uint256 period, uint256 numStandardValidator) public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    numStandardValidator = _bound(numStandardValidator, 0, 10);
    uint256 numRotatingValidator = maxValidator - numGovernanceValidator - numStandardValidator;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked(r, "validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked(r, "staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked(r, "trusted-weight", i))) % 100 + 1;

      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeaconOld.filterAndSaveValidators(
      period, 1, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }

  function testFuzzGas_sortValidatorsByBeacon(uint256 r, uint256 period, uint256 numStandardValidator) public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    numStandardValidator = _bound(numStandardValidator, 0, 10);
    uint256 numRotatingValidator = maxValidator - numGovernanceValidator - numStandardValidator;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked(r, "validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked(r, "staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked(r, "trusted-weight", i))) % 100 + 1;

      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeacon.filterAndSaveValidators(
      period, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }

  function testFuzzGas_sortValidatorsByBeaconAndPickValidatorSet_ForAllEpochs(
    uint256 r,
    uint256 period,
    uint256 numStandardValidator
  ) external {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    numStandardValidator = _bound(numStandardValidator, 0, 10);
    uint256 numRotatingValidator = maxValidator - numGovernanceValidator - numStandardValidator;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked(r, "validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked(r, "staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked(r, "trusted-weight", i))) % 100 + 1;

      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    vm.resumeGasMetering();
    LibSortValidatorsByBeacon.filterAndSaveValidators(
      period, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );

    for (uint256 i = MIN_EPOCH; i <= MAX_EPOCH; i++) {
      LibSortValidatorsByBeacon.pickValidatorSet(1, i, r);
    }
  }

  function testFuzzGas_sortValidatorsByBeaconAndPickValidatorSetOld_ForAllEpochs(
    uint256 r,
    uint256 period,
    uint256 numStandardValidator
  ) external {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    numStandardValidator = _bound(numStandardValidator, 0, 10);
    uint256 numRotatingValidator = maxValidator - numGovernanceValidator - numStandardValidator;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked(r, "validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked(r, "staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked(r, "trusted-weight", i))) % 100 + 1;

      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    vm.resumeGasMetering();
    LibSortValidatorsByBeaconOld.filterAndSaveValidators(
      period, 1, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );

    for (uint256 i = MIN_EPOCH; i <= MAX_EPOCH; i++) {
      LibSortValidatorsByBeaconOld.pickValidatorSet(period, i);
    }
  }

  function testFuzzGas_pickValidatorSet(uint256 r, uint256 period, uint256 numStandardValidator) public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    numStandardValidator = _bound(numStandardValidator, 0, 10);
    uint256 numRotatingValidator = maxValidator - numGovernanceValidator - numStandardValidator;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked(r, "validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked(r, "staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked(r, "trusted-weight", i))) % 100 + 1;

      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    LibSortValidatorsByBeacon.filterAndSaveValidators(
      period, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );

    uint256 pickEpoch = _bound(r, MIN_EPOCH, MAX_EPOCH);

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeacon.pickValidatorSet(0, pickEpoch, r);
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }

  function testFuzzGas_pickValidatorSetOld(uint256 r, uint256 period) public {
    vm.pauseGasMetering();

    uint256 numGovernanceValidator = 12;
    uint256 numStandardValidator = 10;
    uint256 numRotatingValidator = maxValidator - numGovernanceValidator - numStandardValidator;

    address[] memory ids = new address[](threshold);
    uint256[] memory stakedAmounts = new uint256[](threshold);
    uint256[] memory trustedWeights = new uint256[](threshold);

    uint256 c;

    for (uint256 i; i < threshold; i++) {
      ids[i] = vm.addr(uint256(keccak256(abi.encodePacked(r, "validator-id", i))));
      stakedAmounts[i] = 1 ether * (uint256(keccak256(abi.encodePacked(r, "staked-amount", i))) % 1000 + 1);
      uint256 trustedWeight = uint256(keccak256(abi.encodePacked(r, "trusted-weight", i))) % 100 + 1;

      if (c != numGovernanceValidator) {
        trustedWeights[i] = trustedWeight % type(uint16).max;
        c++;
      }
    }

    LibSortValidatorsByBeaconOld.filterAndSaveValidators(
      period, 1, numGovernanceValidator, numStandardValidator, numRotatingValidator, ids, stakedAmounts, trustedWeights
    );

    uint256 pickEpoch = _bound(r, MIN_EPOCH, MAX_EPOCH);

    vm.record();
    vm.resumeGasMetering();
    LibSortValidatorsByBeaconOld.pickValidatorSet(period, pickEpoch);
    vm.pauseGasMetering();
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(this));
    console.log("Reads:", reads.length, "Writes:", writes.length);

    vm.resumeGasMetering();
  }
}

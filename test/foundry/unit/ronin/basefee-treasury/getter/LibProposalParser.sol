// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { JSONParserLib } from "@solady/utils/JSONParserLib.sol";
import { LibString } from "@solady/utils/LibString.sol";

import { console } from "forge-std/console.sol";

import { stdJson } from "forge-std/StdJson.sol";

import { vm } from "@fdk/utils/Helpers.sol";

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";

import { LibArray } from "src/libraries/LibArray.sol";

library LibProposalParser {
  using stdJson for string;

  struct TypedData {
    string primaryType;
    EIP712Domain domain;
    Types types;
    IBaseFeeTreasury.Proposal message;
  }

  struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
  }

  struct Type {
    string name;
    string type_;
  }

  struct Types {
    Type[] EIP712Domain;
    Type[] Proposal;
  }

  function init(TypedData memory mTypedData, uint8 version, uint256 chainId, address verifyingContract) internal pure {
    mTypedData.primaryType = "Proposal";
    mTypedData.domain = EIP712Domain({
      name: "RoninBaseFeeTreasury",
      version: vm.toString(version),
      chainId: chainId,
      verifyingContract: verifyingContract
    });

    mTypedData.types.EIP712Domain = new Type[](4);
    mTypedData.types.EIP712Domain[0] = Type("name", "string");
    mTypedData.types.EIP712Domain[1] = Type("version", "string");
    mTypedData.types.EIP712Domain[2] = Type("chainId", "uint256");
    mTypedData.types.EIP712Domain[3] = Type("verifyingContract", "address");

    mTypedData.types.Proposal = new Type[](7);
    mTypedData.types.Proposal[0] = Type("proposer", "address");
    mTypedData.types.Proposal[1] = Type("nonce", "uint32");
    mTypedData.types.Proposal[2] = Type("expiry", "uint40");
    mTypedData.types.Proposal[3] = Type("executor", "address");
    mTypedData.types.Proposal[4] = Type("recipients", "address[]");
    mTypedData.types.Proposal[5] = Type("amounts", "uint96[]");
    mTypedData.types.Proposal[6] = Type("callDatas", "bytes[]");
  }

  function setMessage(TypedData memory mTypedData, IBaseFeeTreasury.Proposal memory message) internal pure {
    mTypedData.message = message;
  }

  function serialize(TypedData memory mTypedData, string memory path) internal {
    string memory json = "root";
    json.serialize("primaryType", mTypedData.primaryType);

    string memory domain = "domain";
    domain.serialize("name", mTypedData.domain.name);
    domain.serialize("version", mTypedData.domain.version);
    domain.serialize("chainId", mTypedData.domain.chainId);
    domain = domain.serialize("verifyingContract", mTypedData.domain.verifyingContract);

    string memory types = "types";

    string memory eip712Domain = "[";
    for (uint256 i = 0; i < mTypedData.types.EIP712Domain.length; i++) {
      string memory out = "type";
      out.serialize("name", mTypedData.types.EIP712Domain[i].name);
      out = out.serialize("type", mTypedData.types.EIP712Domain[i].type_);

      eip712Domain = string.concat(eip712Domain, out);

      if (i < mTypedData.types.EIP712Domain.length - 1) {
        eip712Domain = string.concat(eip712Domain, ",");
      }
    }
    eip712Domain = string.concat(eip712Domain, "]");
    types.serialize("EIP712Domain", eip712Domain);

    string memory proposal = "[";
    for (uint256 i = 0; i < mTypedData.types.Proposal.length; i++) {
      string memory out = "type";
      out.serialize("name", mTypedData.types.Proposal[i].name);
      out = out.serialize("type", mTypedData.types.Proposal[i].type_);

      proposal = string.concat(proposal, out);

      if (i < mTypedData.types.Proposal.length - 1) {
        proposal = string.concat(proposal, ",");
      }
    }
    proposal = string.concat(proposal, "]");
    types = types.serialize("Proposal", proposal);

    string memory message = "message";
    message.serialize("proposer", mTypedData.message.proposer);
    message.serialize("nonce", mTypedData.message.nonce);
    message.serialize("expiry", mTypedData.message.expiry);
    message.serialize("executor", mTypedData.message.executor);
    message.serialize("recipients", mTypedData.message.recipients);
    message.serialize("amounts", toStringArr(LibArray.toUint256s(mTypedData.message.amounts)));
    message = message.serialize("callDatas", mTypedData.message.callDatas);

    json.serialize("domain", domain);
    json.serialize("types", types);
    json = json.serialize("message", message);

    json = vm.replace(json, '"[', "[");
    json = vm.replace(json, ']"', "]");
    json = vm.replace(json, "\\", "");

    vm.writeFile(path, json);
  }

  function toStringArr(
    uint256[] memory arr
  ) internal pure returns (string[] memory ret) {
    ret = new string[](arr.length);
    for (uint256 i = 0; i < arr.length; i++) {
      ret[i] = vm.toString(arr[i]);
    }
  }
}

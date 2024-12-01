// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibSig } from "@fdk/libraries/LibSig.sol";
import { vme } from "@fdk/utils/Helpers.sol";

import { LibProposalParser } from "./LibProposalParser.sol";
import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";
import { BaseFeeTreasury_Base_Test } from "test/foundry/unit/ronin/basefee-treasury/BaseFeeTreasury.base.t.sol";

contract BaseFeeTreasury_HashProposal_Invariant_Test is BaseFeeTreasury_Base_Test {
  function testFuzz_LibProposalParser_hashProposal(
    IBaseFeeTreasury.Proposal memory proposal
  ) external {
    string memory filePath = "test/foundry/unit/ronin/basefee-treasury/getter/typedData.json";

    LibProposalParser.TypedData memory typedData;
    LibProposalParser.init(typedData, 1, block.chainid, address(baseFeeTreasury));
    LibProposalParser.setMessage(typedData, proposal);
    LibProposalParser.serialize(typedData, filePath);

    (address by, uint256 pk) = makeAddrAndKey("test");
    bytes memory expectedSig = vme.signTypedDataV4(by, filePath, pk);

    bytes32 hash = baseFeeTreasury.hashProposal(proposal);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, hash);
    bytes memory gotSig = LibSig.merge(v, r, s);

    assertEq(keccak256(expectedSig), keccak256(gotSig), "Invalid signature");
  }
}

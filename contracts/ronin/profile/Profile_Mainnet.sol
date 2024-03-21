// SPDX-License-Identifier: MIT

import "./Profile.sol";

pragma solidity ^0.8.9;

contract Profile_Mainnet is Profile {
  modifier hookChangeConsensus() override {
    revert("Not supported");
    _;
  }

  function migrateOldConsensusList(address[] calldata lId, TConsensus[] calldata lCss) external onlyAdmin {
    if (block.chainid != 2020) return;
    require(lId.length == lCss.length, "Invalid length");

    CandidateProfile storage _profile;
    for (uint i; i < lCss.length; ++i) {
      _profile = _id2Profile[lId[i]];
      _profile.oldConsensus = lCss[i];
      _consensus2Id[lCss[i]] = lId[i];
    }
  }
}

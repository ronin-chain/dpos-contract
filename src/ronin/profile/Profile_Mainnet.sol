// SPDX-License-Identifier: MIT

import "./Profile.sol";

pragma solidity ^0.8.9;

contract Profile_Mainnet is Profile {
  modifier hookChangeConsensus() override {
    revert("Not supported");
    _;
  }

  function migrateOmissionREP4() external onlyAdmin {
    if (block.chainid != 2020) return;
    address[] memory omittedCssList = new address[](3);

    omittedCssList[0] = 0x454f6C34F0cfAdF1733044Fdf8B06516BD1E9529;
    omittedCssList[1] = 0xD7fEf73d95ccEdb26483fd3C6C48393e50708159;
    omittedCssList[2] = 0xbD4bf317Da1928CC2f9f4DA9006401f3944A0Ab5;

    CandidateProfile storage _profile;
    for (uint256 i; i < omittedCssList.length; ++i) {
      address id = omittedCssList[i];
      TConsensus css = TConsensus.wrap(id);

      _profile = _id2Profile[id];
      _profile.oldConsensus = css;
      _consensus2Id[css] = id;
    }
  }
}

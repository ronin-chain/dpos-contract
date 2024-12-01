// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBaseFeeTreasury } from "src/interfaces/basefee-treasury/IBaseFeeTreasury.sol";
import { BaseFeeTreasury_Base_Test } from "test/foundry/unit/ronin/basefee-treasury/BaseFeeTreasury.base.t.sol";

contract BaseFeeTreasury_Config_Invariant_Test is BaseFeeTreasury_Base_Test {
  function invariant_ValidThreshold() external view {
    IBaseFeeTreasury.Threshold memory threshold = baseFeeTreasury.getThreshold();
    assertTrue(threshold.num < threshold.denom, "num >= denom");
    assertTrue(threshold.num != 0, "num == 0");
    assertTrue(threshold.denom != 0, "denom == 0");
  }
}

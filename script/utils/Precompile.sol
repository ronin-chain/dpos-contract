// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { GeneralConfig } from "script/GeneralConfig.sol";

contract Precompile {
    function _precompile() private pure {
        bytes memory dummy;
        dummy = type(GeneralConfig).creationCode;
    }
}
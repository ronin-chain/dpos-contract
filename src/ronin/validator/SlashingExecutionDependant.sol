// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/staking/IStaking.sol";
import { HasSlashIndicatorDeprecated, HasStakingDeprecated } from "../../utils/DeprecatedSlots.sol";
import "./storage-fragments/CommonStorage.sol";

abstract contract SlashingExecutionDependant is
  HasContracts,
  HasSlashIndicatorDeprecated,
  HasStakingDeprecated,
  CommonStorage
{ }

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasContracts.sol";
import {
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated,
  HasStakingVestingDeprecated
} from "../../utils/DeprecatedSlots.sol";

import { EmergencyExit } from "./EmergencyExit.sol";
import "./storage-fragments/CommonStorage.sol";

abstract contract CoinbaseExecutionDependant is
  RONTransferHelper,
  HasContracts,
  HasStakingVestingDeprecated,
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated,
  EmergencyExit
{ }

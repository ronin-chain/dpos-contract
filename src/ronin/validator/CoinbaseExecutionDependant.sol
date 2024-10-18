// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import {
  HasStakingVestingDeprecated,
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated
} from "../../utils/DeprecatedSlots.sol";
import "./storage-fragments/CommonStorage.sol";
import { EmergencyExit } from "./EmergencyExit.sol";

abstract contract CoinbaseExecutionDependant is
  RONTransferHelper,
  HasContracts,
  HasStakingVestingDeprecated,
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated,
  EmergencyExit
{ }

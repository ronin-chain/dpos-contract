// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";
import { console } from "forge-std/console.sol";
import { JSONParserLib } from "@solady/utils/JSONParserLib.sol";
import { RoninMigration } from "script/RoninMigration.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";

contract Migration__20240123_MigrateAdmin_Staking is RoninMigration {
  using StdStyle for *;
  using JSONParserLib for *;

  string internal constant MIGRATE_DATA_PATH = "script/data/cid.json";

  function run() external {
    Staking staking = Staking(loadContract(Contract.Staking.key()));
    address migrator = staking.getRoleMember(staking.MIGRATOR_ROLE(), 0);
    console.log("migrator:".yellow(), migrator);
    (address[] memory poolIds, address[] memory admins, bool[] memory flags) = _parseMigrateData(MIGRATE_DATA_PATH);

    vm.broadcast(migrator);
    staking.migrateWasAdmin{ gas: 20_000_000 }(poolIds, admins, flags);
  }

  function _parseMigrateData(string memory path)
    private
    view
    returns (address[] memory poolIds, address[] memory admins, bool[] memory flags)
  {
    string memory raw = vm.readFile(path);
    JSONParserLib.Item memory data = raw.parse();
    uint256 size = data.size();
    console.log("size", size);

    poolIds = new address[](size);
    admins = new address[](size);
    flags = new bool[](size);

    for (uint256 i; i < size; ++i) {
      poolIds[i] = vm.parseAddress(data.at(i).at('"cid"').value().decodeString());
      admins[i] = vm.parseAddress(data.at(i).at('"admin"').value().decodeString());
      flags[i] = true;

      console.log("\nPool ID:".cyan(), vm.toString(poolIds[i]));
      console.log("Admin:".cyan(), vm.toString(admins[i]));
      console.log("Flags:".cyan(), flags[i]);
    }
  }
}

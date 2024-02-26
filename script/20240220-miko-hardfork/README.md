Miko Hardfork Proposal
==================

# Description

Before the proposal, the following items will be prepared:
- A1. An address called `doctor`, which is the temporary admin of BridgeTracking
- A2. A new Governance Admin (GANew) will be deployed
- A3. Snapshot list for `migrateWasAdmin()`

The proposal will do the following tasks:
- B1. Change admin of BridgeTracking to `doctor` (See the After part)
- B2. Deploy all DPoS contracts and upgrade all DPoS contracts
- B3. Reinitialize all DPoS contracts
- C1. The `MIGRATOR_ROLE` in the Staking will migrate the list of `wasAdmin`.
- B4. Replace StableNode's governor address
- B5. Change governance admin of all contracts to (GANew)

After the proposal is executed, the following scripts will be run:
- C2. The `doctor` will withdraw the locked fund.
- C3. The `doctor` will upgrade the Bridge Tracking contract to remove the recovery method.
- C4. The `doctor` will transfer admin to BridgeManager.
- C5. The `doctor` will transfer all fund to Andy's trezor.
- C6. The `migrator` disable the migration method in Staking contract.

# To-fill config

See file [MikoConfig.s.sol](./MikoConfig.s.sol) and fill the `TODO` marks.

# Commands

## Full-flow simulation
```
# Mainnet
./run.sh -f ronin-mainnet script/20240220-miko-hardfork/20240220_Full_shadow_Miko_Hardfork.s.sol -vvvv --legacy
```

## Step-by-step actual run
```
# Mainnet

./run.sh -f ronin-mainnet script/20240220-miko-hardfork/20240220_p1_Miko_before.s.sol -vvvv --legacy --private-keys <BAO_EOA>

./run.sh -f ronin-mainnet script/20240220-miko-hardfork/20240220_p2A_mainnet_Miko_propose_proposal.s.sol -vvvv --legacy --private-keys <GOVERNOR>

./run.sh -f ronin-mainnet script/20240220-miko-hardfork/20240220_p4_Miko_after.s.sol -vvvv --legacy --private-keys <DOCTOR>

./run.sh -f ronin-mainnet script/20240220-miko-hardfork/20240220_p5_Miko_stable.s.sol -vvvv --legacy  --private-keys <MIGRATOR>
```

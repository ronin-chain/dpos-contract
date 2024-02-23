Miko Hardfork Proposal
==================

Before the proposal, the following items will be prepared:
- A1. An address called `doctor`, which is the temporary admin of BridgeTracking
- A2. A new Governance Admin (GANew) will be deployed
- A3. Snapshot list for `migrateWasAdmin()`

The proposal will do the following tasks:
- B1. Change admin of BridgeTracking to `doctor` (See [C2-4])
- B2. Deploy all DPoS contracts and upgrade all DPoS contracts
- B3. Reinitialize all DPoS contracts
- C1. The `MIGRATOR_ROLE` in the Staking will migrate the list of `wasAdmin`.
- B4. Replace StableNode's governor address
- B5. Change governance admin of all contracts to (GANew)

After the proposal is executed, the following scripts will be run:
- C2. The `doctor` will withdraw the locked fund.
- C3. The `doctor` will upgrade the Bridge Tracking contract to remove the recovery method.
- C4. The `doctor` will transfer admin to BridgeManager.
Miko Hardfork Proposal
==================

Before the proposal, the following items will be prepared:
- An address called `doctor`, which is the temporary admin of BridgeTracking
- A new Governance Admin (GANew) will be deployed
- Snapshot list for `migrateWasAdmin()`

The proposal will do the following tasks:
B1. Change admin of BridgeTracking to `doctor` (See [After 2-3])
B2. Deploy all DPoS contracts and upgrade all DPoS contracts
B3. Reinitialize all DPoS contracts
B4. Change governance admin of all contracts to (GANew)

After the proposal is executed, the following scripts will be run:
C1. The `MIGRATOR_ROLE` in the Staking will migrate the list of `wasAdmin`.
C2. The `doctor` will withdraw the locked fund.
C3. The `doctor` will upgrade the Bridge Tracking contract to remove the recovery method.
C4. The `doctor` will transfer admin to BridgeManager.
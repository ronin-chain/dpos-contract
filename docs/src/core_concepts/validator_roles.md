# Roles Explained

This document explains the key roles in the Delegated Proof of Stake (DPoS) system, with a focus on validators, their responsibilities, and the hierarchical structure within the Ronin network.

---

## 1. Candidate

### Definition

- A **candidate** is an entity that applies to become a validator.
- Candidates must meet specific requirements, such as staking a minimum amount of tokens.
- Candidates hold specific data:
  - `admin`: The address used for rotating the consensus address and other information, identical to the treasury address.
  - `treasury`: The address to receive rewards, identical to the admin address.
  - `governor`: Used for voting on proposals; only governing validators have this information.
  - `commissionRate`: The percentage of rewards the validator shares with their delegators.
  - `pubKeyHash`: Hash of the public key used to vote for finality.
  - `vrfKeyHash`: Hash of the VRF key used to submit random seeds; only governing validators have this information.

### Responsibilities

- Maintain their staking balance to remain eligible for promotion.
- Await selection to join the validator set.
- Submit fast finality proofs to finalize blocks.

### Process

1. A user applies to become a candidate by calling the `applyValidatorCandidate` function in the smart contract.
2. Eligible candidates may be promoted to validator status.

---

## 2. Validator

### Definition

- A **validator** is a candidate that has been selected to participate in block production and governance of the network.
- Validators are divided into three types:
  1. **Governing Validators (GV)**: Trusted entities with governance privileges.
  2. **Standard Validators (SV)**: Selected based on their staking amounts.
  3. **Rotating Validators (RV)**: Temporarily promoted validators selected randomly for fairness.

---

### Types of Validators

#### 1. **Governing Validators (GV)**

- **Role**: Act as core participants in network governance and block production.
- **Selection**: Chosen based on predefined trusted organization weights.
- **Special Privileges**:
  - Submit VRF proofs to generate random seeds.
  - Participate in voting for proposals and changes to network parameters.
  - Maintain a public `vrfKeyHash` and `governor` address for governance.

#### 2. **Standard Validators (SV)**

- **Role**: Provide block production support with no governance privileges.
- **Selection**: Chosen based on staking amounts from the top-ranked candidates after governing validators.
- **Special Privileges**:
  - Contribute to block production.
  - Earn rewards from transaction fees and block rewards.
- **Limitation**: Excluded from voting on governance proposals.

#### 3. **Rotating Validators (RV)**

- **Role**: Promote decentralization by allowing temporary participation.
- **Selection**:
  - Randomly selected from the remaining candidates after GV and SV are assigned.
  - Determined by the random seed generated during beacon finalization.
- **Special Privileges**:
  - Participate in block production during assigned epochs.
- **Limitation**:
  - Rotation occurs periodically; their validator status is not permanent.

---

### Responsibilities of Validators

- **Block Production**:
  - Validate and include transactions in blocks.
  - Produce blocks during assigned epochs.
- **Finality Proofs**:
  - All candidates, including non-block producers, contribute fast finality proofs to finalize blocks.
- **Compliance**:
  - Maintain active participation to avoid penalties or slashing.
  - Ensure sufficient staking to retain validator status.

---

## 3. Block Producer

### Definition

- A **block producer** is a validator assigned to create blocks during a specific epoch.

### Responsibilities

- Validate transactions and include them in new blocks.

### Key Points

- Block producers are a subset of validators assigned to create blocks during specific epochs.
- All candidates (not just block producers) are responsible for submitting finality proofs.

---

## 4. Delegator

### Definition

- A **delegator** is a token holder who stakes their tokens with a validator.
- Delegators share in validator rewards and indirectly influence governance by supporting specific validators.

### Reward Sharing

- Rewards are distributed based on:
  - Validator's commission rate.
  - Delegator's staked amount.

---

## 5. Hierarchical Relationship

### Structure

1. **Candidates**: The initial pool of participants awaiting promotion.
2. **Validators**:
   - Governing Validators (GV): Trusted and responsible for governance and block production.
   - Standard Validators (SV): Support block production without governance roles.
   - Rotating Validators (RV): Temporarily promoted to encourage decentralization.
3. **Block Producers**: A subset of validators responsible for creating blocks during specific epochs.
4. **Delegators**: Stake tokens with validators to share in rewards and indirectly support the network.

---

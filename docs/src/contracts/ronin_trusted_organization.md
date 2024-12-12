# Ronin Trusted Organization Contract Documentation

---

## Overview

The `RoninTrustedOrganization` contract is responsible for managing governor keys and weights for governing validators..

---

## Core Logic

### 1. Trusted Organization Management

The contract provides `RoninGovernanceAdmin` with the ability to manage trusted organizations, which include:

- **Consensus Address**: Represents the operational node account.
- **Governor Address**: An externally owned account (EOA) used for voting on governance proposals.
- **Weight**: All governors are assigned the same weight for governance decisions, ensuring equal influence.

Management operations include:

- **Create, Update, and Delete (CRUD)** trusted organizations.

---

### 2. Quorum Thresholds

The contract sets a threshold for achieving quorum in governance decisions:

- **Threshold Parameters**:
  - **Numerator (`_num`)** and **Denominator (`_denom`)** are used to define the quorum percentage required for a decision to pass.

---

### 3. Threshold Evaluation

To ensure governance decisions are valid, the contract evaluates votes against the quorum threshold:

- **Minimum Vote Weight**:
  - Computes the minimum required vote weight to meet the quorum.
- **Threshold Check**:
  - Validates whether the provided vote weight meets or exceeds the quorum percentage.

---

### 4. Data Integrity and Sanity Checks

The contract enforces strict data integrity for trusted organization management:

- **Sanity Checks**:
  - Validates that weights are greater than zero.
  - Ensures that the consensus address, governor address, and deprecated bridge voter address are unique.
- **Duplicate Prevention**:
  - Prevent duplication of addresses in the organization mappings.

---

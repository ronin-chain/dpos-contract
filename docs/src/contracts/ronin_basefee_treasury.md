# Ronin BaseFee Treasury

---

## Overview

The `RoninBaseFeeTreasury` contract serves as a treasury for collecting and managing base fees from EIP1559 transactions.

---

## Core Logic

### 1. Receiving Funds

When an EIP-1559 transaction occurs, the Ronin node directs the base fee to this treasury contract.

- **Base Fee Source**: The base fee from EIP-1559 transactions is automatically credited to the contract’s balance by the underlying node logic.

### 2. Managing Balances

The contract holds the collected base fees securely, ensuring that the Ether remains within the contract balance until explicitly withdrawn through `RoninGovernanceAdmin` voting process.

- The balance of the contract reflects the cumulative base fees collected from network transactions.

### 3. Integration with Node Logic

The Ronin node interacts directly with this contract as part of the EIP-1559 fee mechanism:

- **Node Behavior**: Upon processing a transaction, the node routes the base fee to the `RoninBaseFeeTreasury`.
- **Automatic Updates**: The contract balance is updated dynamically based on incoming base fees from node-managed transactions.

---

## Purpose

- **Base Fee Treasury**: Acts as a dedicated repository for EIP-1559 base fees, ensuring the funds are securely stored and managed.

---

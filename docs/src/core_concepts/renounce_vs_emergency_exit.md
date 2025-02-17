# Overview: Comparing Emergency Exit and Renounce Processes

---

## Introduction

This document highlights the differences between the **Emergency Exit** and **Renounce** processes available to validators in the Ronin network. Both mechanisms allow validators to exit their roles, but they serve distinct purposes and workflows. Additionally, their impact on a validator's block production role and candidate status varies significantly.

---

## Key Differences

| Feature                        | **Emergency Exit**                                                                                | **Renounce**                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **Purpose**                    | For validators facing exceptional circumstances.                                                  | For validators voluntarily stepping down.                                               |
| **Eligibility**                | Available to all validators.                                                                      | Restricted for governing validators.                                                    |
| **Stake Handling**             | Stake is locked during the process and managed by governance.                                     | Stake remains unaffected; role renunciation is scheduled.                               |
| **Governance Voting**          | Requires governor approval through an emergency exit poll.                                        | No governance voting required.                                                          |
| **Impact on Block Production** | Block producer role is disabled immediately after the next epoch.                                 | Candidate continues to join validator selection process until the revocation timestamp. |
| **Impact on Candidate List**   | Remains in candidate list until period ending of the revoking timestamp and eligible for rewards. | Same as renounce                                                                        |
| **Fund Recycling**             | Locked funds are recycled if the poll expires.                                                    | No recycling mechanism; funds remain intact.                                            |

---

## Emergency Exit Process

- **Use Case**: Designed for validators encountering unexpected issues, such as security threats, operational failures, or loss of private keys.
- **Governance Role**:
  - Governors must vote on an **emergency exit poll**.
  - Approval releases the validator’s locked stake; disapproval or expiration results in recycling the stake.
- **Impact on Block Production**:
  - The validator is removed as a block producer starting from the next epoch.
  - Ensures immediate mitigation of risks from compromised validators.
- **Impact on Candidate Status**:
  - The validator remains in the candidate list util the period ending of revoking timestamp.
- **Fund Management**:
  - Locked funds are securely managed in `RoninValidatorSet`.
  - Upon poll expiration, locked funds are recycled into the `StakingVesting` contract.
- **Outcome**:
  - The validator is removed from block production and candidate list.

---

## Renounce Process

- **Use Case**: Allows validators to voluntarily step down while maintaining network continuity.
- **Governance Role**:
  - Non-governing validators can renounce freely.
  - Governing validators cannot renounce due to their critical role in governance.
- **Impact on Block Production**:
  - The candidate continues to join validator selection and responsibilities until the revocation timestamp is reached.
- **Impact on Candidate Status**:
  - The validator remains fully eligible for rewards and voting until the revocation timestamp.
- **Fund Management**:
  - No stake is locked or recycled during the process.
- **Outcome**:
  - The validator exits the set after the revocation timestamp, allowing for controlled role handover.

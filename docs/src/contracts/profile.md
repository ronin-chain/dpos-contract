# Profile

---

## Key Highlights

### Source of Truth for Validator Data

- The `Profile` contract serves as the **centralized registry** for all validator-related information, including consensus addresses, treasury accounts, admin details, and cryptographic keys.
- It maintains the integrity and accuracy of validator data, ensuring reliable governance and staking operations.

### Cross-Contract Interactions

- Integrates seamlessly with other Ronin contracts to facilitate dynamic updates:
  - **Staking Contract**: Automatically updates profiles when a candidate applies for validator roles.
  - **RoninValidatorSet**: Provides essential validator data for operations like consensus participation and governance voting.
- Changes to key profile attributes (e.g., consensus or public keys) trigger updates in dependent contracts to maintain consistency across the ecosystem.

### Centralized Mapping for Data Integrity

- Uses a **single mapping** as the registry for all validator profile data.
- Ensures that critical data (e.g., public keys, VRF key hashes, consensus addresses) is unique across the network, preventing duplication and maintaining trust in the system.

---

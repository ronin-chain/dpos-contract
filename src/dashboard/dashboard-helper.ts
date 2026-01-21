import { Address, Deployment } from 'hardhat-deploy/dist/types';
import { DEFAULT_ADDRESS } from '../utils';
import { ethers } from 'hardhat';

/**
 * EIP-1967 Admin Slot constant.
 * bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
 */
export const EIP1967_ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';

/**
 * Validates if the current admin matches the expected admin address.
 * Standardizes addresses to checksum format before comparison for security.
 */
export function isCorrectAdmin(admin: Address, expectedAdmin: Address): boolean {
  if (!expectedAdmin || expectedAdmin === DEFAULT_ADDRESS) return false;
  
  try {
    return ethers.utils.getAddress(admin) === ethers.utils.getAddress(expectedAdmin);
  } catch {
    // Fallback to case-insensitive comparison if address format is invalid
    return admin.toLowerCase() === expectedAdmin.toLowerCase();
  }
}

/**
 * Retrieves the admin address from a proxy's dedicated EIP-1967 storage slot.
 * Ensures the returned value is a valid Ethereum address.
 * * @param address The address of the proxy contract
 * @returns The hex-encoded address of the proxy admin
 */
export const getAdminOfProxy = async (address: Address): Promise<string> => {
  const slotValue = await ethers.provider.getStorageAt(address, EIP1967_ADMIN_SLOT);
  
  // Extract the last 20 bytes (40 chars) which represent the address
  const adminAddress = ethers.utils.hexDataSlice(slotValue, 12);
  
  if (adminAddress === ethers.constants.AddressZero) {
    return ethers.constants.AddressZero;
  }

  return ethers.utils.getAddress(adminAddress);
};

export interface ProxyManagementInfo {
  deployment: Deployment | null;
  address?: Address;
  admin?: Address;
  expectedAdmin?: Address;
  isCorrect?: boolean; // Fixed: Use primitive boolean
}

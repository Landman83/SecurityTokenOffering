// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICompliance
 * @notice Interface for token compliance checks
 */
interface ICompliance {
    /**
     * @notice Check if a token is a TREX token
     * @param token The address of the token to check
     * @return True if the token is a TREX token, false otherwise
     */
    function isTREX(address token) external view returns (bool);
    
    /**
     * @notice Check if a user is an agent of a TREX token
     * @param token The address of the token to check
     * @param user The address of the user to check
     * @return True if the user is an agent of the token, false otherwise
     */
    function isTREXAgent(address token, address user) external view returns (bool);
    
    /**
     * @notice Check if a user is the owner of a TREX token
     * @param token The address of the token to check
     * @param user The address of the user to check
     * @return True if the user is the owner of the token, false otherwise
     */
    function isTREXOwner(address token, address user) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IAgentRole
 * @notice Interface for the AgentRole contract
 */
interface IAgentRole {
    /**
     * @notice Check if an address is an agent
     * @param _agent The address to check
     * @return True if the address is an agent, false otherwise
     */
    function isAgent(address _agent) external view returns (bool);
}
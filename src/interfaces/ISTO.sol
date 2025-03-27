// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Interface for the Security Token Offering (STO) contract
 */
interface ISTO {
    /**
     * @notice Issue tokens to a specific investor
     * @param _investor Address of the investor
     * @param _amount Amount of tokens to issue
     */
    function issueTokens(address _investor, uint256 _amount) external;
}
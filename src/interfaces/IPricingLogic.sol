// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Interface for pricing logic in STOs
 */
interface IPricingLogic {
    /**
     * @notice Calculate the number of tokens to be issued for a given investment amount
     * @param _investedAmount Amount of tokens invested
     * @return tokens Number of security tokens to be issued
     * @return refund Amount to be refunded (if any)
     */
    function calculateTokenAmount(uint256 _investedAmount) external view returns (uint256 tokens, uint256 refund);
    
    /**
     * @notice Get the current rate for token purchases
     * @return The current conversion rate
     */
    function getCurrentRate() external view returns (uint256);
}
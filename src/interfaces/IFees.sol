// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IFees
 * @notice Interface for the fee management logic
 */
interface IFees {
    /**
     * @notice Get the current fee rate in basis points (1 = 0.01%)
     * @return The current fee rate in basis points
     */
    function getFeeRate() external view returns (uint256);
    
    /**
     * @notice Get the fee wallet address
     * @return The address of the fee wallet
     */
    function getFeeWallet() external view returns (address);
    
    /**
     * @notice Calculate the fee amount for a given total amount
     * @param _totalAmount The total amount to calculate fee from
     * @return feeAmount The calculated fee amount
     * @return remainingAmount The remaining amount after fee deduction
     */
    function calculateFee(uint256 _totalAmount) external view returns (uint256 feeAmount, uint256 remainingAmount);
    
    /**
     * @notice Set a new fee rate in basis points
     * @param _newFeeRate The new fee rate in basis points (1 = 0.01%)
     */
    function setFeeRate(uint256 _newFeeRate) external;
    
    /**
     * @notice Set a new fee wallet address
     * @param _newFeeWallet The new fee wallet address
     */
    function setFeeWallet(address _newFeeWallet) external;
}
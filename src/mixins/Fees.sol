// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IFees.sol";
import "../libraries/Events.sol";

/**
 * @title Fees
 * @notice Implements fee calculation and management for STOs
 * @dev Collects x% of investment tokens raised as fee and sends to fee wallet
 */
contract Fees is IFees {
    // Fee rate in basis points (100 = 1%)
    uint256 public feeRate;
    
    // Fee wallet address
    address public feeWallet;
    
    // Maximum allowed fee rate in basis points (10% = 1000)
    uint256 public constant MAX_FEE_RATE = 1000;
    
    // Owner address with admin permissions
    address public owner;
    
    /**
     * @dev Constructor to set up the fees contract
     * @param _feeRate Initial fee rate in basis points (100 = 1%, 200 = 2%)
     * @param _feeWallet Address to receive fees
     * @param _owner Address that can update fee settings
     */
    constructor(uint256 _feeRate, address _feeWallet, address _owner) {
        require(_feeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");
        require(_feeWallet != address(0), "Fee wallet cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        
        feeRate = _feeRate;
        feeWallet = _feeWallet;
        owner = _owner;
    }
    
    /**
     * @dev Modifier to restrict function access to owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @notice Get the current fee rate in basis points
     * @return The current fee rate in basis points
     */
    function getFeeRate() external view override returns (uint256) {
        return feeRate;
    }
    
    /**
     * @notice Get the fee wallet address
     * @return The address of the fee wallet
     */
    function getFeeWallet() external view override returns (address) {
        return feeWallet;
    }
    
    /**
     * @notice Calculate the fee amount for a given total amount
     * @param _totalAmount The total amount to calculate fee from
     * @return feeAmount The calculated fee amount
     * @return remainingAmount The remaining amount after fee deduction
     */
    function calculateFee(uint256 _totalAmount) external view override returns (uint256 feeAmount, uint256 remainingAmount) {
        feeAmount = (_totalAmount * feeRate) / 10000; // 10000 basis points = 100%
        remainingAmount = _totalAmount - feeAmount;
        return (feeAmount, remainingAmount);
    }
    
    /**
     * @notice Set a new fee rate in basis points
     * @param _newFeeRate The new fee rate in basis points (1 = 0.01%)
     */
    function setFeeRate(uint256 _newFeeRate) external override onlyOwner {
        require(_newFeeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");
        feeRate = _newFeeRate;
        emit Events.FeeRateChanged(_newFeeRate);
    }
    
    /**
     * @notice Set a new fee wallet address
     * @param _newFeeWallet The new fee wallet address
     */
    function setFeeWallet(address _newFeeWallet) external override onlyOwner {
        require(_newFeeWallet != address(0), "Fee wallet cannot be zero address");
        feeWallet = _newFeeWallet;
        emit Events.FeeWalletChanged(_newFeeWallet);
    }
    
    /**
     * @notice Transfer ownership of the fee contract
     * @param _newOwner The new owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
        emit Events.FeeOwnershipTransferred(_newOwner);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Events
 * @dev Library containing all events used in the STO system
 */
library Events {
    // CappedSTO events
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event SetAllowBeneficialInvestments(bool allowed);
    event STOFinalized(bool softCapReached);
    
    // Cap events
    event SoftCapReached();
    event HardCapReached();
    
    // Escrow events
    event FundsDeposited(address indexed investor, uint256 amount, uint256 tokenAllocation);
    event FundsReleased(address indexed wallet, uint256 amount);
    event EscrowFinalized(bool softCapReached);
    event STOClosed(bool hardCapReached, bool endTimeReached);
    
    // Refund events
    event RefundsInitialized();
    event RefundClaimed(address indexed investor, uint256 amount);
    
    // Minting events
    event MintingInitialized();
    event TokensDelivered(address indexed investor, uint256 amount);
    
    // Pricing events
    event RateChanged(uint256 newRate);
}

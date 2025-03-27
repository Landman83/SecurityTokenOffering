// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Errors
 * @dev Library containing all error messages used in the STO system
 */
library Errors {
    // General errors
    string constant ZERO_ADDRESS = "Zero address is not permitted";
    string constant UNAUTHORIZED = "Caller is not authorized";
    string constant ALREADY_INITIALIZED = "Already initialized";
    string constant NOT_OPERATOR = "Caller is not the operator";
    
    // STO errors
    string constant NOT_STARTED = "STO not started";
    string constant ENDED = "STO has ended";
    string constant CLOSED = "STO is closed";
    string constant NOT_CLOSED = "STO is not closed";
    string constant ALREADY_FINALIZED = "STO is already finalized";
    
    // Cap errors
    string constant HARD_CAP_REACHED = "Hard cap reached";
    string constant SOFT_CAP_NOT_REACHED = "Soft cap not reached";
    
    // Investment errors
    string constant ZERO_INVESTMENT = "Investment amount must be greater than 0";
    string constant BELOW_MIN_INVESTMENT = "Investment amount below minimum";
    
    // Pricing errors
    string constant ZERO_RATE = "Rate must be greater than 0";
    
    // Escrow errors
    string constant ESCROW_NOT_FINALIZED = "Escrow not finalized";
    string constant ESCROW_ALREADY_FINALIZED = "Escrow already finalized";
    
    // Refund errors
    string constant ALREADY_CLAIMED_REFUND = "Already claimed refund";
    string constant NO_REFUND_AVAILABLE = "No refund available";
    
    // Minting errors
    string constant ALREADY_CLAIMED_TOKENS = "Already claimed tokens";
    string constant NO_TOKENS_TO_CLAIM = "No tokens to claim";
}
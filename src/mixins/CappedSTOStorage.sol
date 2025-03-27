// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../storage/STOStorage.sol";

/**
 * @title Storage contract for CappedSTO
 */
contract CappedSTOStorage is STOStorage {
    // The rate of token per investment token (multiplied by 10^18)
    uint256 public rate;
    
    // Hard cap for backward compatibility
    uint256 public cap;
    
    // Address where investment token funds are collected
    address payable public wallet;
    
    // Total number of unique investors
    uint256 public investorCount;
    
    // Allow beneficiary to be different from sender
    bool public allowBeneficialInvestments;
}
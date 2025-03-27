// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Base storage contract for STO
 */
contract STOStorage {
    // The start time of the offering
    uint256 public startTime;
    
    // The end time of the offering
    uint256 public endTime;
    
    // Enum for fund raise types
    enum FundRaiseType { ETH, POLY, DAI, USDT, USDC, ERC20 }
    
    // Whether STOs of a fund raise type are allowed
    mapping(uint8 => bool) public fundRaiseTypes;
    
    // Amount of funds raised per fund raise type
    mapping(uint8 => uint256) public fundsRaised;
    
    // Total number of tokens sold
    uint256 private tokensSold;
}
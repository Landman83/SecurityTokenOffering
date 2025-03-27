// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PricingLogic.sol";
import "../interfaces/IFixedPrice.sol";
import "../libraries/Errors.sol";
import "../libraries/Events.sol";

/**
 * @title Fixed price STO
 * @notice Tokens offered at fixed price
 */
contract FixedPrice is PricingLogic, IFixedPrice {
    // Rate of token per investment token (multiplied by 10^18)
    uint256 public rate;
    
    // Address with permission to change rate
    address public operator;
    
    /**
     * @notice Initialize the contract with a fixed rate
     * @param _securityToken Address of the security token
     * @param _rate Rate of token per investment token (multiplied by 10^18)
     * @param _operator Address with permission to update rate
     */
    constructor(
        address _securityToken,
        uint256 _rate,
        address _operator
    ) PricingLogic(_securityToken) {
        require(_rate > 0, Errors.ZERO_RATE);
        require(_operator != address(0), Errors.ZERO_ADDRESS);
        
        rate = _rate;
        operator = _operator;
    }
    
    /**
     * @notice Set the rate for token purchases
     * @param _rate New rate for token purchases (tokens per investment token * 10^18)
     */
    function setRate(uint256 _rate) external override {
        require(msg.sender == operator, Errors.NOT_OPERATOR);
        require(_rate > 0, Errors.ZERO_RATE);
        
        rate = _rate;
        emit Events.RateChanged(_rate);
    }
    
    /**
     * @notice Calculate the number of tokens to be issued for a given investment amount
     * @param _investedAmount Amount of tokens invested
     * @return tokens Number of security tokens to be issued
     * @return refund Amount to be refunded (if any)
     */
    function calculateTokenAmount(uint256 _investedAmount) external view override(IPricingLogic, PricingLogic) returns (uint256 tokens, uint256 refund) {
        require(_investedAmount >= minInvestment, Errors.BELOW_MIN_INVESTMENT);
        
        // Calculate tokens based on rate
        tokens = _investedAmount * rate / (10 ** 18);
        
        // Adjust for granularity
        uint256 adjustedTokens = _adjustForGranularity(tokens);
        
        // Calculate any refund due to rounding
        if (adjustedTokens < tokens) {
            uint256 actualCost = adjustedTokens * (10 ** 18) / rate;
            refund = _investedAmount - actualCost;
            tokens = adjustedTokens;
        } else {
            tokens = adjustedTokens;
            refund = 0;
        }
    }
    
    /**
     * @notice Get the current rate for token purchases
     * @return The current conversion rate
     */
    function getCurrentRate() external view override(IPricingLogic, PricingLogic) returns (uint256) {
        return rate;
    }
}
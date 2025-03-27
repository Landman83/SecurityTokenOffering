// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IPricingLogic.sol";
import "../libraries/Errors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@Rule506c/token/IToken.sol";

/**
 * @title Abstract contract for pricing logic in STOs
 */
abstract contract PricingLogic is IPricingLogic {
    // The security token being sold
    IToken public securityToken;
    
    // Minimum investment amount
    uint256 public minInvestment;
    
    constructor(address _securityToken) {
        require(_securityToken != address(0), Errors.ZERO_ADDRESS);
        securityToken = IToken(_securityToken);
    }
    
    /**
     * @notice Set minimum investment amount
     * @param _minInvestment Minimum amount that can be invested
     */
    function setMinInvestment(uint256 _minInvestment) public {
        minInvestment = _minInvestment;
    }
    
    /**
     * @notice Adjust tokens for granularity
     * @param _tokens Number of tokens to adjust
     * @return Tokens adjusted to token granularity
     */
    function _adjustForGranularity(uint256 _tokens) internal view returns (uint256) {
        // Default granularity is 1 (standard for ERC20 tokens)
        uint256 granularity = 1;
        return _tokens / granularity * granularity;
    }
    
    /**
     * @notice Calculate the number of tokens to be issued for a given investment amount
     * @param _investedAmount Amount of tokens invested
     * @return tokens Number of security tokens to be issued
     * @return refund Amount to be refunded (if any)
     */
    function calculateTokenAmount(uint256 _investedAmount) external view virtual override returns (uint256 tokens, uint256 refund);
    
    /**
     * @notice Get the current rate for token purchases
     * @return The current conversion rate
     */
    function getCurrentRate() external view virtual override returns (uint256);
}
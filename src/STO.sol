// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/ISTO.sol";
import "@Rule506c/token/IToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./storage/STOStorage.sol";

/**
 * @title Security Token Offering (STO) base contract
 * @notice Abstract base contract for all STO implementations
 */
abstract contract STO is ISTO {
    // The security token being sold
    address public securityToken;
    
    // Flag to determine if this is a Rule506c compliant offering or simple ERC20 offering
    bool public isRule506cOffering;
    
    // Permission constants
    bytes32 internal constant OPERATOR = keccak256("OPERATOR_ROLE");

    /**
     * @notice Constructor
     * @param _securityToken Address of the security token
     * @param _isRule506c Flag indicating if this is a Rule506c compliant offering
     */
    constructor(address _securityToken, bool _isRule506c) {
        require(_securityToken != address(0), "Security token address cannot be zero");
        securityToken = _securityToken;
        isRule506cOffering = _isRule506c;
    }
    
    /**
     * @notice Check if an address has a specific permission
     * @param _delegate Address to check
     * @param _permission Permission to check
     * @return Whether the address has the permission
     */
    function hasPermission(address _delegate, bytes32 _permission) internal view virtual returns(bool);
    
    /**
     * @notice Set the fund raise types
     * @param _fundRaiseTypes Array of fund raise types
     */
    function _setFundRaiseType(STOStorage.FundRaiseType[] memory _fundRaiseTypes) internal virtual {
        // Implementation to be provided by derived contracts
    }
}
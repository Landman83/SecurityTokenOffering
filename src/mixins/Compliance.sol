// Only allows KYC verified users to participate in STOs

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICompliance.sol";
import "../interfaces/IAgentRole.sol";
import "@Rule506c/token/IToken.sol";
import "@Rule506c/registry/interface/IIdentityRegistry.sol";

/**
 * @title Compliance
 * @notice Implementation of token compliance checks
 */
contract Compliance is Ownable, ICompliance {
    constructor(address initialOwner) Ownable(initialOwner) {}
    /**
     * @notice Check if a token is a TREX token
     * @param token The address of the token to check
     * @return True if the token is a TREX token, false otherwise
     */
    function isTREX(address token) public view override returns (bool) {
        try IToken(token).identityRegistry() returns (IIdentityRegistry _ir) {
            if (address(_ir) != address(0)) {
                return true;
            }
            return false;
        }
        catch {
            return false;
        }
    }
    
    /**
     * @notice Check if a user is an agent of a TREX token
     * @param token The address of the token to check
     * @param user The address of the user to check
     * @return True if the user is an agent of the token, false otherwise
     */
    function isTREXAgent(address token, address user) public view override returns (bool) {
        if (isTREX(token)){
            return IAgentRole(token).isAgent(user);
        }
        return false;
    }
    
    /**
     * @notice Check if a user is the owner of a TREX token
     * @param token The address of the token to check
     * @param user The address of the user to check
     * @return True if the user is the owner of the token, false otherwise
     */
    function isTREXOwner(address token, address user) public view override returns (bool) {
        if (isTREX(token)){
            return Ownable(token).owner() == user;
        }
        return false;
    }
}

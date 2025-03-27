// Allows investors to withdraw funds from escrow contract while STO is open
// Handles automatic refunds if soft cap is not reached

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Escrow.sol";

/**
 * @title Refund
 * @dev Handles refund logic when soft cap is not reached
 */
contract Refund is ReentrancyGuard {
    // The STO contract
    address public sto;
    
    // The escrow contract
    Escrow public escrow;
    
    // The investment token
    IERC20 public investmentToken;
    
    // Mapping of investor address to their refund amount
    mapping(address => uint256) public refunds;
    
    // Whether refunds have been initialized
    bool public initialized;
    
    /**
     * @dev Emitted when refunds are initialized
     */
    event RefundsInitialized();
    
    /**
     * @dev Emitted when a refund is claimed
     */
    event RefundClaimed(address indexed investor, uint256 amount);
    
    /**
     * @dev Modifier to ensure only the escrow contract can call certain functions
     */
    modifier onlyEscrow() {
        require(msg.sender == address(escrow), "Caller is not the escrow");
        _;
    }
    
    /**
     * @dev Constructor to set up the refund contract
     * @param _escrow Address of the escrow contract
     * @param _investmentToken Address of the investment token
     */
    constructor(address _escrow, address _investmentToken) {
        require(_escrow != address(0), "Escrow address cannot be zero");
        require(_investmentToken != address(0), "Investment token address cannot be zero");
        
        escrow = Escrow(_escrow);
        investmentToken = IERC20(_investmentToken);
        initialized = false;
    }
    
    /**
     * @dev Initialize refunds from the escrow contract
     * @param _sto Address of the STO contract
     */
    function initializeRefunds(address _sto) external onlyEscrow nonReentrant {
        require(!initialized, "Refunds already initialized");
        require(_sto != address(0), "STO address cannot be zero");
        
        sto = _sto;
        initialized = true;
        
        emit RefundsInitialized();
    }
    
    /**
     * @dev Claim a refund
     */
    function claimRefund() external nonReentrant {
        require(initialized, "Refunds not initialized");
        
        uint256 amount = escrow.getInvestment(msg.sender);
        require(amount > 0, "No investment to refund");
        
        // Mark as refunded to prevent double claims
        refunds[msg.sender] = amount;
        
        // Transfer tokens from escrow to investor
        bool success = investmentToken.transferFrom(address(escrow), msg.sender, amount);
        require(success, "Refund transfer failed");
        
        emit RefundClaimed(msg.sender, amount);
    }
    
    /**
     * @dev Check if an investor has claimed their refund
     * @param _investor Address of the investor
     * @return Whether the investor has claimed their refund
     */
    function hasClaimedRefund(address _investor) external view returns (bool) {
        return refunds[_investor] > 0;
    }
    
    /**
     * @dev Get the refund amount for an investor
     * @param _investor Address of the investor
     * @return Refund amount
     */
    function getRefundAmount(address _investor) external view returns (uint256) {
        if (!initialized) return 0;
        return escrow.getInvestment(_investor);
    }
}

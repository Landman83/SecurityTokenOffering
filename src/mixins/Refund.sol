// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Escrow.sol";

/**
 * @title Refund
 * @dev Handles refund logic for investors when:
 * 1. They want to withdraw funds before offering closes
 * 2. Soft cap is not reached and offering is finalized
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
    
    // List of investors for batch processing
    address[] private investors;
    
    /**
     * @dev Emitted when refunds are initialized
     */
    event RefundsInitialized();
    
    /**
     * @dev Emitted when a refund is processed
     */
    event RefundProcessed(address indexed investor, uint256 amount);
    
    /**
     * @dev Emitted when an investor withdraws funds before offering closes
     */
    event WithdrawalProcessed(address indexed investor, uint256 amount);
    
    /**
     * @dev Modifier to ensure only the escrow contract can call certain functions
     */
    modifier onlyEscrow() {
        require(msg.sender == address(escrow), "Caller is not the escrow");
        _;
    }
    
    /**
     * @dev Modifier to ensure only the STO contract can call certain functions
     */
    modifier onlySTO() {
        require(msg.sender == sto, "Caller is not the STO");
        _;
    }
    
    /**
     * @dev Constructor to set up the refund contract
     * @param _escrow Address of the escrow contract
     * @param _investmentToken Address of the investment token
     * @param _sto Address of the STO contract
     */
    constructor(address _escrow, address _investmentToken, address _sto) {
        require(_escrow != address(0), "Escrow address cannot be zero");
        require(_investmentToken != address(0), "Investment token address cannot be zero");
        require(_sto != address(0), "STO address cannot be zero");
        
        escrow = Escrow(_escrow);
        investmentToken = IERC20(_investmentToken);
        sto = _sto;
        initialized = false;
    }
    
    /**
     * @dev Initialize refunds from the escrow contract
     * @param _sto Address of the STO contract - for verification
     */
    function initializeRefunds(address _sto) external onlyEscrow nonReentrant {
        require(!initialized, "Refunds already initialized");
        require(_sto != address(0), "STO address cannot be zero");
        require(_sto == sto, "STO address mismatch");
        
        initialized = true;
        
        emit RefundsInitialized();
    }
    
    /**
     * @dev Manually claim a refund after soft cap failure
     * Note: This should only be needed if the automatic refund process failed
     */
    function claimRefund() external nonReentrant {
        require(initialized, "Refunds not initialized");
        
        uint256 amount = escrow.getInvestment(msg.sender);
        require(amount > 0, "No investment to refund");
        require(refunds[msg.sender] == 0, "Refund already processed");
        
        // Mark as refunded to prevent double claims
        refunds[msg.sender] = amount;
        
        // Transfer tokens from escrow to investor
        bool success = investmentToken.transferFrom(address(escrow), msg.sender, amount);
        require(success, "Refund transfer failed");
        
        emit RefundProcessed(msg.sender, amount);
    }
    
    /**
     * @dev Process refunds for all investors (called automatically when soft cap not reached)
     * @param _investors Array of investor addresses
     */
    function processRefundsForAll(address[] calldata _investors) external onlySTO nonReentrant {
        require(initialized, "Refunds not initialized");
        
        for (uint256 i = 0; i < _investors.length; i++) {
            address investor = _investors[i];
            
            // Skip if already refunded
            if (refunds[investor] > 0) continue;
            
            uint256 amount = escrow.getInvestment(investor);
            if (amount > 0) {
                // Mark as refunded
                refunds[investor] = amount;
                
                // Transfer tokens from escrow to investor
                bool success = investmentToken.transferFrom(address(escrow), investor, amount);
                if (success) {
                    emit RefundProcessed(investor, amount);
                }
            }
        }
    }
    
    /**
     * @dev Allow an investor to withdraw some or all of their investment before offering closes
     * @param _investor Address of the investor
     * @param _amount Amount to withdraw
     */
    function withdraw(address _investor, uint256 _amount) external onlySTO nonReentrant {
        require(!escrow.isSTOClosed(), "STO is already closed");
        require(!escrow.isFinalized(), "Escrow is already finalized");
        
        uint256 investment = escrow.getInvestment(_investor);
        require(investment >= _amount, "Withdrawal amount exceeds investment");
        
        // Mark as withdrawn in refunds mapping to track partial withdrawals
        refunds[_investor] += _amount;
        
        // Call escrow to process the withdrawal (it will handle token transfer)
        escrow.processWithdrawal(_investor, _amount);
        
        emit WithdrawalProcessed(_investor, _amount);
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

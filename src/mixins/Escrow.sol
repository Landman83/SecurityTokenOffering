/* Handles escrow logic
    - Funds held in escrow until STO is closed
    - STO closed at end of STO period or when hard cap is reached
    - If soft cap is not reached, funds are returned to investors via Refund.sol
    - If STO closes and soft cap is reached, Rule506c tokens are minted and delivered to investors via Minting.sol
*/

// Need to add onchain-id KYC compliance checks before allowing investing

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../STO.sol";
import "./Cap.sol";
import "./Refund.sol";
import "./Minting.sol";
import "../interfaces/IFees.sol";
import "../libraries/Events.sol";

/**
 * @title Escrow
 * @dev Handles escrow logic for STOs
 * - Funds held in escrow until STO is closed
 * - STO closed at end of STO period or when hard cap is reached
 * - If soft cap is not reached, funds are returned to investors via Refund.sol
 * - If STO closes and soft cap is reached, Rule506c tokens are minted and delivered to investors via Minting.sol
 * - Investors can withdraw their investment before offering closes
 */
contract Escrow is ReentrancyGuard {
    // The STO contract that owns this escrow
    address public sto;
    
    // The security token being sold
    IERC20 public securityToken;
    
    // The token being used for investment
    IERC20 public investmentToken;
    
    // The wallet to receive funds when released
    address public wallet;
    
    // The refund contract
    Refund public refundContract;
    
    // The minting contract
    Minting public mintingContract;
    
    // The fees contract
    IFees public feesContract;
    
    // Mapping of investor address to their investment amount
    mapping(address => uint256) public investments;
    
    // Mapping of investor address to their token allocation
    mapping(address => uint256) public tokenAllocations;
    
    // Mapping of investor address to their withdrawn amount (before offering closes)
    mapping(address => uint256) public withdrawals;
    
    // Total investment amount held in escrow
    uint256 public totalInvestment;
    
    // Total tokens allocated
    uint256 public totalTokensAllocated;
    
    // Whether the escrow has been finalized
    bool public finalized;
    
    // Whether the soft cap was reached
    bool public softCapReached;
    
    // Whether the STO is closed
    bool public stoClosed;
    
    /**
     * @dev Emitted when funds are deposited into escrow
     */
    event FundsDeposited(address indexed investor, uint256 amount, uint256 tokenAllocation);
    
    /**
     * @dev Emitted when funds are released to the wallet
     */
    event FundsReleased(address indexed wallet, uint256 amount);
    
    /**
     * @dev Emitted when escrow is finalized
     */
    event EscrowFinalized(bool softCapReached);
    
    /**
     * @dev Emitted when STO is closed
     */
    event STOClosed(bool hardCapReached, bool endTimeReached);
    
    /**
     * @dev Modifier to ensure only the STO contract can call certain functions
     */
    modifier onlySTO() {
        require(msg.sender == sto, "Caller is not the STO");
        _;
    }
    
    /**
     * @dev Modifier to ensure the escrow has not been finalized
     */
    modifier notFinalized() {
        require(!finalized, "Escrow already finalized");
        _;
    }
    
    /**
     * @dev Modifier to ensure the STO is not closed
     */
    modifier stoNotClosed() {
        require(!stoClosed, "STO is closed");
        _;
    }
    
    /**
     * @dev Constructor to set up the escrow
     * @param _sto Address of the STO contract
     * @param _securityToken Address of the security token
     * @param _investmentToken Address of the investment token
     * @param _wallet Address to receive funds when released
     * @param _refundContract Address of the refund contract
     * @param _mintingContract Address of the minting contract
     * @param _feesContract Address of the fees contract (optional)
     */
    constructor(
        address _sto,
        address _securityToken,
        address _investmentToken,
        address _wallet,
        address _refundContract,
        address _mintingContract,
        address _feesContract
    ) {
        require(_sto != address(0), "STO address cannot be zero");
        require(_securityToken != address(0), "Security token address cannot be zero");
        require(_investmentToken != address(0), "Investment token address cannot be zero");
        require(_wallet != address(0), "Wallet address cannot be zero");
        require(_refundContract != address(0), "Refund contract address cannot be zero");
        require(_mintingContract != address(0), "Minting contract address cannot be zero");
        
        sto = _sto;
        securityToken = IERC20(_securityToken);
        investmentToken = IERC20(_investmentToken);
        wallet = _wallet;
        refundContract = Refund(_refundContract);
        mintingContract = Minting(_mintingContract);
        
        // Set fees contract if provided
        if (_feesContract != address(0)) {
            feesContract = IFees(_feesContract);
        }
        finalized = false;
        softCapReached = false;
        stoClosed = false;
    }
    
    /**
     * @dev Deposit funds into escrow and allocate tokens
     * @param _investor Address of the investor
     * @param _amount Amount of investment tokens
     * @param _tokenAllocation Amount of security tokens to allocate
     */
    function deposit(address _investor, uint256 _amount, uint256 _tokenAllocation) 
        external 
        onlySTO 
        notFinalized 
        stoNotClosed 
        nonReentrant 
    {
        require(_investor != address(0), "Investor address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");
        require(_tokenAllocation > 0, "Token allocation must be greater than zero");
        
        // Transfer investment tokens from STO to escrow
        bool success = investmentToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Investment token transfer failed");
        
        // Update investor records
        investments[_investor] += _amount;
        tokenAllocations[_investor] += _tokenAllocation;
        
        // Update totals
        totalInvestment += _amount;
        totalTokensAllocated += _tokenAllocation;
        
        emit FundsDeposited(_investor, _amount, _tokenAllocation);
    }
    
    /**
     * @dev Process a withdrawal of funds by an investor before offering closes
     * @param _investor Address of the investor
     * @param _amount Amount to withdraw
     */
    function processWithdrawal(address _investor, uint256 _amount) 
        external 
        onlySTO 
        notFinalized 
        stoNotClosed 
        nonReentrant 
    {
        require(_investor != address(0), "Investor address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");
        
        // Check if investor has enough funds to withdraw
        uint256 currentInvestment = investments[_investor] - withdrawals[_investor];
        require(currentInvestment >= _amount, "Withdrawal amount exceeds available investment");
        
        // Update withdrawal record
        withdrawals[_investor] += _amount;
        
        // Calculate token allocation to reduce - proportional to withdrawal amount
        uint256 tokenReduction = (tokenAllocations[_investor] * _amount) / investments[_investor];
        
        // Update token allocation
        tokenAllocations[_investor] -= tokenReduction;
        
        // Update totals
        totalInvestment -= _amount;
        totalTokensAllocated -= tokenReduction;
        
        // Transfer tokens back to investor
        bool success = investmentToken.transfer(_investor, _amount);
        require(success, "Withdrawal transfer failed");
    }
    
    /**
     * @dev Close the STO when hard cap is reached or end time is reached
     * @param _hardCapReached Whether the hard cap was reached
     * @param _endTimeReached Whether the end time was reached
     */
    function closeSTO(bool _hardCapReached, bool _endTimeReached) 
        external 
        onlySTO 
        notFinalized 
        stoNotClosed 
        nonReentrant 
    {
        require(_hardCapReached || _endTimeReached, "STO can only be closed if hard cap or end time is reached");
        
        stoClosed = true;
        emit STOClosed(_hardCapReached, _endTimeReached);
    }
    
    /**
     * @dev Finalize the escrow based on whether soft cap was reached
     * @param _softCapReached Whether the soft cap was reached
     */
    function finalize(bool _softCapReached) 
        external 
        onlySTO 
        notFinalized 
        nonReentrant 
    {
        require(stoClosed, "STO must be closed before finalizing");
        
        softCapReached = _softCapReached;
        finalized = true;
        
        if (softCapReached) {
            uint256 balance = investmentToken.balanceOf(address(this));
            if (balance > 0) {
                // Process fees if a fee contract is set
                if (address(feesContract) != address(0)) {
                    // Calculate fee
                    (uint256 feeAmount, uint256 remainingAmount) = feesContract.calculateFee(balance);
                    address feeWallet = feesContract.getFeeWallet();
                    
                    if (feeAmount > 0 && feeWallet != address(0)) {
                        // Transfer fee to fee wallet
                        bool feeSuccess = investmentToken.transfer(feeWallet, feeAmount);
                        require(feeSuccess, "Failed to transfer fee");
                        emit Events.FeeCollected(feeWallet, feeAmount);
                        
                        // Transfer remaining amount to project wallet
                        bool walletSuccess = investmentToken.transfer(wallet, remainingAmount);
                        require(walletSuccess, "Failed to release funds to wallet");
                        emit FundsReleased(wallet, remainingAmount);
                    } else {
                        // No fee to collect, transfer everything to wallet
                        bool success = investmentToken.transfer(wallet, balance);
                        require(success, "Failed to release funds to wallet");
                        emit FundsReleased(wallet, balance);
                    }
                } else {
                    // No fee contract, transfer everything to wallet
                    bool success = investmentToken.transfer(wallet, balance);
                    require(success, "Failed to release funds to wallet");
                    emit FundsReleased(wallet, balance);
                }
            }
            
            // Transfer investor data to minting contract
            mintingContract.initializeInvestors(sto);
        } else {
            // Transfer investor data to refund contract
            refundContract.initializeRefunds(sto);
        }
        
        emit EscrowFinalized(softCapReached);
    }
    
    /**
     * @dev Get investment amount for an investor (accounts for any withdrawals)
     * @param _investor Address of the investor
     * @return Investment amount
     */
    function getInvestment(address _investor) external view returns (uint256) {
        return investments[_investor] - withdrawals[_investor];
    }
    
    /**
     * @dev Get total amount invested by an investor (original investment)
     * @param _investor Address of the investor
     * @return Total investment amount
     */
    function getTotalInvestment(address _investor) external view returns (uint256) {
        return investments[_investor];
    }
    
    /**
     * @dev Get total amount withdrawn by an investor
     * @param _investor Address of the investor
     * @return Withdrawn amount
     */
    function getWithdrawnAmount(address _investor) external view returns (uint256) {
        return withdrawals[_investor];
    }
    
    /**
     * @dev Get token allocation for an investor
     * @param _investor Address of the investor
     * @return Token allocation
     */
    function getTokenAllocation(address _investor) external view returns (uint256) {
        return tokenAllocations[_investor];
    }
    
    /**
     * @dev Check if the STO is closed
     * @return Whether the STO is closed
     */
    function isSTOClosed() external view returns (bool) {
        return stoClosed;
    }
    
    /**
     * @dev Check if the escrow is finalized
     * @return Whether the escrow is finalized
     */
    function isFinalized() external view returns (bool) {
        return finalized;
    }
    
    /**
     * @dev Check if the soft cap was reached
     * @return Whether the soft cap was reached
     */
    function isSoftCapReached() external view returns (bool) {
        return softCapReached;
    }
}



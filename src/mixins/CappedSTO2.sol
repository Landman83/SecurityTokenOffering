// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../STO.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CappedSTOStorage.sol";
import "./Cap.sol";
import "./Escrow.sol";
import "./Refund.sol";
import "./Minting.sol";

/**
 * @title STO module for standard capped crowdsale using ERC20 token
 */
contract CappedSTO is CappedSTOStorage, STO, ReentrancyGuard, Cap {
    // The token being used for the investment
    IERC20 public investmentToken;
    
    // The escrow contract
    Escrow public escrow;
    
    // The refund contract
    Refund public refund;
    
    // The minting contract
    Minting public minting;
    
    // Array to keep track of all investors
    address[] private investors;
    
    // Mapping to check if an address is already in the investors array
    mapping(address => bool) private isInvestor;

    /**
    * Event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value amount of investment tokens paid
    * @param amount amount of security tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event SetAllowBeneficialInvestments(bool _allowed);
    
    /**
    * Event for STO finalization
    */
    event STOFinalized(bool softCapReached);

    constructor(address _securityToken, address _polyToken) 
        Module(_securityToken, _polyToken)
    {
        // Constructor initialization
    }

    /**
     * @notice Function used to intialize the contract variables
     * @param _startTime Unix timestamp at which offering get started
     * @param _endTime Unix timestamp at which offering get ended
     * @param _hardCap Maximum No. of token base units for sale (hard cap)
     * @param _softCap Minimum No. of token base units that must be sold (soft cap)
     * @param _rate Token units a buyer gets multiplied by 10^18 per investment token unit
     * @param _fundsReceiver Account address to hold the funds
     * @param _investmentToken Address of the ERC20 token used for investment
     */
    function configure(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _hardCap,
        uint256 _softCap,
        uint256 _rate,
        address payable _fundsReceiver,
        address _investmentToken
    )
        public
        onlyFactory
    {
        require(endTime == 0, "Already configured");
        require(_rate > 0, "Rate of token should be greater than 0");
        require(_fundsReceiver != address(0), "Zero address is not permitted");
        require(_investmentToken != address(0), "Investment token cannot be zero address");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Date parameters are not valid");
        
        // Initialize Cap contract with new values
        _initialize(_hardCap, _softCap);
        
        startTime = _startTime;
        endTime = _endTime;
        cap = _hardCap; // Keep for backward compatibility
        rate = _rate;
        wallet = _fundsReceiver;
        investmentToken = IERC20(_investmentToken);
        
        // Create the minting and refund contracts first
        minting = new Minting(address(this));
        refund = new Refund(address(this), _investmentToken);
        
        // Create the escrow contract with references to minting and refund
        escrow = new Escrow(
            address(this),
            address(securityToken),
            _investmentToken,
            _fundsReceiver,
            address(refund),
            address(minting)
        );
        
        // Set ERC20 as the only fund raise type
        FundRaiseType[] memory fundRaiseTypes = new FundRaiseType[](1);
        fundRaiseTypes[0] = FundRaiseType.ERC20;
        _setFundRaiseType(fundRaiseTypes);
    }

    /**
     * @notice This function returns the signature of configure function
     */
    function getInitFunction() public pure returns(bytes4) {
        return this.configure.selector;
    }

    /**
     * @notice Function to set allowBeneficialInvestments (allow beneficiary to be different to funder)
     * @param _allowBeneficialInvestments Boolean to allow or disallow beneficial investments
     */
    function changeAllowBeneficialInvestments(bool _allowBeneficialInvestments) public withPerm(OPERATOR) {
        require(_allowBeneficialInvestments != allowBeneficialInvestments, "Does not change value");
        allowBeneficialInvestments = _allowBeneficialInvestments;
        emit SetAllowBeneficialInvestments(allowBeneficialInvestments);
    }

    /**
     * @notice Purchase tokens with ERC20 token
     * @param _beneficiary Address performing the token purchase
     * @param _investedAmount Amount of ERC20 tokens to invest
     */
    function buyTokens(address _beneficiary, uint256 _investedAmount) public whenNotPaused nonReentrant {
        if (!allowBeneficialInvestments) {
            require(_beneficiary == msg.sender, "Beneficiary address does not match msg.sender");
        }

        require(_investedAmount > 0, "Investment amount must be greater than 0");
        require(!escrow.isSTOClosed(), "STO is closed");
        
        // Transfer tokens from investor to this contract
        bool success = investmentToken.transferFrom(msg.sender, address(this), _investedAmount);
        require(success, "Token transfer failed");
        
        // Approve escrow to take tokens from this contract
        success = investmentToken.approve(address(escrow), _investedAmount);
        require(success, "Approval failed");
        
        // Process the transaction
        (uint256 tokens, uint256 refund) = _processTx(_beneficiary, _investedAmount);
        
        // Track investor for later use
        if (!isInvestor[_beneficiary]) {
            investors.push(_beneficiary);
            isInvestor[_beneficiary] = true;
            investorCount++;
        }
        
        // If there's a refund, send it back to the investor
        if (refund > 0) {
            success = investmentToken.transfer(msg.sender, refund);
            require(success, "Refund transfer failed");
        }
        
        emit TokenPurchase(msg.sender, _beneficiary, _investedAmount - refund, tokens);
        
        // Check if hard cap is reached and close STO if needed
        if (hardCapReached()) {
            escrow.closeSTO(true, false);
        }
    }

    /**
     * @notice Claim refund if soft cap was not reached
     */
    function claimRefund() public nonReentrant {
        require(escrow.isFinalized(), "Escrow not finalized");
        require(!escrow.isSoftCapReached(), "Soft cap was reached, no refunds available");
        
        refund.claimRefund();
    }
    
    /**
     * @notice Claim tokens if soft cap was reached
     */
    function claimTokens() public nonReentrant {
        require(escrow.isFinalized(), "Escrow not finalized");
        require(escrow.isSoftCapReached(), "Soft cap not reached, no tokens available");
        
        minting.mintAndDeliverTokens(msg.sender);
    }
    
    /**
     * @notice Batch mint tokens to multiple investors
     * @param _investors Array of investor addresses
     */
    function batchMintTokens(address[] calldata _investors) public withPerm(OPERATOR) nonReentrant {
        require(escrow.isFinalized(), "Escrow not finalized");
        require(escrow.isSoftCapReached(), "Soft cap not reached, no tokens available");
        
        minting.batchMintAndDeliverTokens(_investors);
    }
    
    /**
     * @notice Finalize the offering
     * @dev Can only be called after the offering end time or when hard cap is reached
     */
    function finalize() public withPerm(OPERATOR) {
        require(block.timestamp > endTime || hardCapReached(), "Offering not yet ended and hard cap not reached");
        
        // Close the STO if not already closed
        if (!escrow.isSTOClosed()) {
            escrow.closeSTO(hardCapReached(), block.timestamp > endTime);
        }
        
        // Finalize the escrow if not already finalized
        if (!escrow.isFinalized()) {
            escrow.finalize(isSoftCapReached());
        }
        
        emit STOFinalized(isSoftCapReached());
    }
    
    /**
     * @notice Issue tokens to a specific investor
     * @param _investor Address of the investor
     * @param _amount Amount of tokens to issue
     */
    function issueTokens(address _investor, uint256 _amount) external {
        require(msg.sender == address(minting), "Only minting contract can call this function");
        securityToken.issue(_investor, _amount, "");
    }

    /**
     * @notice Receive function to handle direct ETH transfers
     */
    receive() external payable {
        revert("Direct ETH payments not accepted");
    }

    /**
     * @notice Fallback function to handle function calls with no matching signature
     */
    fallback() external payable {
        revert("Function not supported");
    }

    /**
     * @notice Return the total no. of tokens sold
     */
    function getTokensSold() external view returns (uint256) {
        return getTotalTokensSold();
    }

    /**
     * @notice Return the permissions flag that are associated with STO
     */
    function getPermissions() public view returns(bytes32[] memory) {
        bytes32[] memory allPermissions = new bytes32[](1);
        allPermissions[0] = OPERATOR;
        return allPermissions;
    }

    /**
     * @notice Return the STO details
     */
    function getSTODetails() public view returns(
        uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, address, bool, bool
    ) {
        return (
            startTime, 
            endTime, 
            getHardCap(), 
            getSoftCap(),
            rate, 
            fundsRaised[uint8(FundRaiseType.ERC20)], 
            investorCount, 
            getTotalTokensSold(),
            address(investmentToken),
            getSoftCapReached(),
            escrow.isSTOClosed()
        );
    }

    /**
     * @notice Get all investors
     */
    function getAllInvestors() external view returns (address[] memory) {
        return investors;
    }

    /**
     * @notice Check if an investor has claimed their tokens
     * @param _investor Address of the investor
     */
    function hasClaimedTokens(address _investor) external view returns (bool) {
        return minting.hasClaimedTokens(_investor);
    }
    
    /**
     * @notice Check if an investor has claimed their refund
     * @param _investor Address of the investor
     */
    function hasClaimedRefund(address _investor) external view returns (bool) {
        return refund.hasClaimedRefund(_investor);
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------
    /**
     * Processing the purchase as well as verify the required validations
     * @param _beneficiary Address performing the token purchase
     * @param _investedAmount Value in investment tokens involved in the purchase
     * @return tokens Number of tokens to be purchased
     * @return refund Amount to be refunded
     */
    function _processTx(address _beneficiary, uint256 _investedAmount) internal returns(uint256 tokens, uint256 refund) {
        _preValidatePurchase(_beneficiary, _investedAmount);
        
        // Calculate token amount to be created
        (tokens, refund) = _getTokenAmount(_investedAmount);
        uint256 netInvestment = _investedAmount - refund;

        // Update state
        fundsRaised[uint8(FundRaiseType.ERC20)] += netInvestment;
        
        // Update tokens sold and check if soft cap is reached
        _updateTokensSold(tokens);
        
        // Deposit funds and token allocation in escrow
        escrow.deposit(_beneficiary, netInvestment, tokens);
        
        return (tokens, refund);
    }

    /**
     * @notice Validation of an incoming purchase.
     */
    function _preValidatePurchase(address _beneficiary, uint256 _investedAmount) internal view {
        require(_beneficiary != address(0), "Beneficiary address should not be 0x");
        require(_investedAmount != 0, "Amount invested should not be equal to 0");
        require(_canBuy(_beneficiary), "Unauthorized");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Offering is closed/Not yet started");
        require(!hardCapReached(), "Hard cap reached");
    }

    /**
     * @notice Overrides to extend the way in which investment tokens are converted to security tokens.
     */
    function _getTokenAmount(uint256 _investedAmount) internal view returns(uint256 tokens, uint256 refund) {
        tokens = _investedAmount * rate / (10 ** 18);
        
        // Use the Cap module to calculate the allowed amount
        uint256 allowedTokens = _calculateAllowedAmount(tokens);
        if (allowedTokens < tokens) {
            tokens = allowedTokens;
        }
        
        uint256 granularity = securityToken.granularity();
        tokens = tokens / granularity * granularity;
        
        require(tokens > 0, "Cap reached");
        
        refund = _investedAmount - (tokens * (10 ** 18)) / rate;
    }
}
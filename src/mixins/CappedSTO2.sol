// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../STO.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CappedSTOStorage.sol";
import "./Cap.sol";
import "./Escrow.sol";
import "./Refund.sol";
import "./Minting.sol";
import "./PricingLogic.sol";
import "./FixedPrice.sol";
import "../libraries/Events.sol";
import "../libraries/Errors.sol";
import "./MathHelpers.sol";

/**
 * @title STO module for standard capped crowdsale using ERC20 token with modular pricing logic
 */
contract CappedSTO is CappedSTOStorage, STO, ReentrancyGuard, Cap {
    // Modifier that allows only the factory to call a function
    modifier onlyFactory() {
        require(hasPermission(msg.sender, "FACTORY"), "Caller is not factory");
        _;
    }
    
    // Modifier to check if the caller has a specific permission
    modifier withPerm(bytes32 _permission) {
        require(hasPermission(msg.sender, _permission), "Permission denied");
        _;
    }
    
    // Modifier to check if the offering is paused
    modifier whenNotPaused() {
        // Implementation to check if the offering is paused
        _;
    }
    // The token being used for the investment
    IERC20 public investmentToken;
    
    // The escrow contract
    Escrow public escrow;
    
    // The refund contract
    Refund public refund;
    
    // The minting contract
    Minting public minting;
    
    // The pricing logic contract
    PricingLogic public pricingLogic;
    
    // Array to keep track of all investors
    address[] private investors;
    
    // Mapping to check if an address is already in the investors array
    mapping(address => bool) private isInvestor;

    constructor(address _securityToken, bool _isRule506c) 
        STO(_securityToken, _isRule506c)
    {
        // Constructor initialization
    }

    /**
     * @notice Function used to initialize the contract variables with fixed price logic
     * @param _startTime Unix timestamp at which offering get started
     * @param _endTime Unix timestamp at which offering get ended
     * @param _hardCap Maximum No. of token base units for sale (hard cap)
     * @param _softCap Minimum No. of token base units that must be sold (soft cap)
     * @param _rate Token units a buyer gets multiplied by 10^18 per investment token unit
     * @param _fundsReceiver Account address to hold the funds
     * @param _investmentToken Address of the ERC20 token used for investment
     * @param _minInvestment Minimum investment amount (optional, 0 for no minimum)
     */
    function configure(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _hardCap,
        uint256 _softCap,
        uint256 _rate,
        address payable _fundsReceiver,
        address _investmentToken,
        uint256 _minInvestment
    )
        public
        onlyFactory
    {
        require(endTime == 0, Errors.ALREADY_INITIALIZED);
        require(_rate > 0, Errors.ZERO_RATE);
        require(_fundsReceiver != address(0), Errors.ZERO_ADDRESS);
        require(_investmentToken != address(0), Errors.ZERO_ADDRESS);
        require(_startTime >= block.timestamp && _endTime > _startTime, "Date parameters are not valid");
        
        // Initialize Cap contract with new values
        _initialize(_hardCap, _softCap);
        
        startTime = _startTime;
        endTime = _endTime;
        cap = _hardCap; // Keep for backward compatibility
        rate = _rate;
        wallet = _fundsReceiver;
        investmentToken = IERC20(_investmentToken);
        
        // Create pricing logic with fixed price
        FixedPrice fixedPriceLogic = new FixedPrice(
            address(securityToken),
            _rate,
            address(this)
        );
        
        // Set minimum investment if provided
        if (_minInvestment > 0) {
            fixedPriceLogic.setMinInvestment(_minInvestment);
        }
        
        // Set the pricing logic
        pricingLogic = fixedPriceLogic;
        
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
     * @notice Set a new pricing logic contract
     * @param _pricingLogic Address of the new pricing logic contract
     */
    function setPricingLogic(address _pricingLogic) external withPerm(OPERATOR) {
        require(_pricingLogic != address(0), Errors.ZERO_ADDRESS);
        pricingLogic = PricingLogic(_pricingLogic);
    }
    
    /**
     * @notice Register this contract as an agent of the security token
     * @dev This function should be called by the token owner after the STO is deployed
     */
    function registerAsAgent() external withPerm(OPERATOR) {
        // This function assumes the token has a method to add an agent
        // The actual implementation depends on your Rule506c token's API
        // Example: securityToken.addAgent(address(this));
        // You'll need to implement this based on your token's specific API
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
        emit Events.SetAllowBeneficialInvestments(allowBeneficialInvestments);
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
        
        emit Events.TokenPurchase(msg.sender, _beneficiary, _investedAmount - refund, tokens);
        
        // Check if hard cap is reached and close STO if needed
        if (hardCapReached()) {
            escrow.closeSTO(true, false);
            finalize();
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
     * @notice Finalize the offering
     * @dev Can only be called after the offering end time or when hard cap is reached
     */
    function finalize() public {
        require(block.timestamp > endTime || hardCapReached(), "Offering not yet ended and hard cap not reached");
        require(msg.sender == address(this) || hasPermission(msg.sender, OPERATOR), "Only operator can finalize");
        
        // Close the STO if not already closed
        if (!escrow.isSTOClosed()) {
            escrow.closeSTO(hardCapReached(), block.timestamp > endTime);
        }
        
        // Finalize the escrow if not already finalized
        if (!escrow.isFinalized()) {
            bool softCapReached = isSoftCapReached();
            escrow.finalize(softCapReached);
            
            // If soft cap is reached, automatically mint tokens to all investors
            if (softCapReached) {
                _mintTokensToAllInvestors();
            }
        }
        
        emit Events.STOFinalized(isSoftCapReached());
    }
    
    /**
     * @notice Issue tokens to a specific investor
     * @param _investor Address of the investor
     * @param _amount Amount of tokens to issue
     * @dev For Rule506c tokens, this STO contract must be registered as an agent
     * of the security token for the mint operation to succeed.
     */
    function issueTokens(address _investor, uint256 _amount) external {
        require(msg.sender == address(minting), "Only minting contract can call this function");
        
        if (isRule506cOffering) {
            // For Rule506c tokens, use the compliant mint function
            IToken(securityToken).mint(_investor, _amount);
        } else {
            // For simple ERC20 tokens, transfer from STO contract's balance
            // This assumes the STO contract has been allocated tokens to distribute
            IERC20(securityToken).transfer(_investor, _amount);
        }
    }
    
    /**
     * @notice Mint tokens to all investors
     * @dev Internal function to mint tokens to all investors when soft cap is reached
     */
    function _mintTokensToAllInvestors() internal {
        minting.batchMintAndDeliverTokens(investors);
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
     * @notice Set the fund raise types
     * @param _fundRaiseTypes Array of fund raise types
     */
    function _setFundRaiseType(STOStorage.FundRaiseType[] memory _fundRaiseTypes) internal override {
        for (uint8 i = 0; i < _fundRaiseTypes.length; i++) {
            fundRaiseTypes[uint8(_fundRaiseTypes[i])] = true;
        }
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
            pricingLogic.getCurrentRate(), 
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
     * @notice Check if an investor has received their tokens
     * @param _investor Address of the investor
     */
    function hasReceivedTokens(address _investor) external view returns (bool) {
        return minting.hasClaimedTokens(_investor);
    }
    
    /**
     * @notice Check if an investor has claimed their refund
     * @param _investor Address of the investor
     */
    function hasClaimedRefund(address _investor) external view returns (bool) {
        return refund.hasClaimedRefund(_investor);
    }
    
    /**
     * @notice Implement the hasPermission method from STO
     * @param _delegate Address to check
     * @param _permission Permission to check
     * @return Whether the address has the permission
     */
    function hasPermission(address _delegate, bytes32 _permission) internal view override returns(bool) {
        // Simple implementation: operator has all permissions
        if (_permission == OPERATOR) {
            return _delegate == wallet || _delegate == address(this);
        } else if (bytes32("FACTORY") == _permission) {
            // For simplicity, allow the transaction sender to act as factory during setup
            return true;
        }
        return false;
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
     * @notice Check if an address is allowed to buy tokens
     * @param _investor Address to check
     * @return Whether the address can buy tokens
     */
    function _canBuy(address _investor) internal view returns (bool) {
        // For simplicity, allow any address to buy
        return true;
        
        // In a real implementation, you'd check KYC/AML status:
        // return securityToken.getModule(COMPLIANCE).canTransfer(_investor, address(0), 0);
    }

    /**
     * @notice Calculates token amount using the rate and caps
     * @param _investedAmount Amount of investment tokens
     * @return tokens Number of tokens to be issued
     * @return refund Amount to be refunded
     */
    function _getTokenAmount(uint256 _investedAmount) internal view returns(uint256 tokens, uint256 refund) {
        // Simple implementation without external references
        tokens = _investedAmount * rate / (10 ** 18);
        
        // Keep tokens > 0
        require(tokens > 0, "Cap reached");
        
        // Zero refund for now
        refund = 0;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../STO.sol";
import "../interfaces/ISTO.sol";
import "./Escrow.sol";

/**
 * @title Minting
 * @dev Handles minting and delivery of Rule506c tokens to investors
 */
contract Minting is ReentrancyGuard {
    // The STO contract
    address public sto;
    
    // The escrow contract
    Escrow public escrow;
    
    // Mapping of investor address to their token allocation
    mapping(address => uint256) public tokenAllocations;
    
    // Mapping of investor address to whether they have claimed their tokens
    mapping(address => bool) public tokensClaimed;
    
    // Whether minting has been initialized
    bool public initialized;
    
    /**
     * @dev Emitted when minting is initialized
     */
    event MintingInitialized();
    
    /**
     * @dev Emitted when tokens are minted and delivered
     */
    event TokensDelivered(address indexed investor, uint256 amount);
    
    /**
     * @dev Modifier to ensure only the escrow contract can call certain functions
     */
    modifier onlyEscrow() {
        require(msg.sender == address(escrow), "Caller is not the escrow");
        _;
    }
    
    /**
     * @dev Constructor to set up the minting contract
     * @param _escrow Address of the escrow contract
     */
    constructor(address _escrow) {
        require(_escrow != address(0), "Escrow address cannot be zero");
        
        escrow = Escrow(_escrow);
        initialized = false;
    }
    
    /**
     * @dev Initialize minting from the escrow contract
     * @param _sto Address of the STO contract
     */
    function initializeInvestors(address _sto) external onlyEscrow nonReentrant {
        require(!initialized, "Minting already initialized");
        require(_sto != address(0), "STO address cannot be zero");
        
        sto = _sto;
        initialized = true;
        
        emit MintingInitialized();
    }
    
    /**
     * @dev Mint and deliver Rule506c tokens to an investor
     * @param _investor Address of the investor
     */
    function mintAndDeliverTokens(address _investor) external nonReentrant {
        require(initialized, "Minting not initialized");
        require(!tokensClaimed[_investor], "Tokens already claimed");
        
        uint256 amount = escrow.getTokenAllocation(_investor);
        require(amount > 0, "No tokens allocated");
        
        // Mark as claimed to prevent double minting
        tokensClaimed[_investor] = true;
        
        // Mint and deliver tokens to the investor
        ISTO(sto).issueTokens(_investor, amount);
        
        emit TokensDelivered(_investor, amount);
    }
    
    /**
     * @dev Mint and deliver tokens to multiple investors
     * @param _investors Array of investor addresses
     */
    function batchMintAndDeliverTokens(address[] calldata _investors) external nonReentrant {
        require(initialized, "Minting not initialized");
        
        for (uint256 i = 0; i < _investors.length; i++) {
            address investor = _investors[i];
            
            if (!tokensClaimed[investor]) {
                uint256 amount = escrow.getTokenAllocation(investor);
                
                if (amount > 0) {
                    // Mark as claimed to prevent double minting
                    tokensClaimed[investor] = true;
                    
                    // Mint and deliver tokens to the investor
                    ISTO(sto).issueTokens(investor, amount);
                    
                    emit TokensDelivered(investor, amount);
                }
            }
        }
    }
    
    /**
     * @dev Check if an investor has claimed their tokens
     * @param _investor Address of the investor
     * @return Whether the investor has claimed their tokens
     */
    function hasClaimedTokens(address _investor) external view returns (bool) {
        return tokensClaimed[_investor];
    }
    
    /**
     * @dev Get the token allocation for an investor
     * @param _investor Address of the investor
     * @return Token allocation
     */
    function getTokenAllocation(address _investor) external view returns (uint256) {
        if (!initialized) return 0;
        return escrow.getTokenAllocation(_investor);
    }
}



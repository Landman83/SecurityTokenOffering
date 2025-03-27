// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Cap
 * @dev Contract module that provides soft and hard cap enforcement logic
 */
abstract contract Cap {
    // Hard cap - maximum amount of tokens that can be sold
    uint256 private _hardCap;
    
    // Soft cap - minimum amount of tokens that must be sold
    uint256 private _softCap;
    
    // Whether the soft cap has been reached
    bool private _softCapReached;
    
    // Total tokens sold
    uint256 private _totalTokensSold;
    
    // Whether the contract has been initialized
    bool private _initialized;
    
    /**
     * @dev Emitted when soft cap is reached
     */
    event SoftCapReached();
    
    /**
     * @dev Constructor with default values
     * Real values will be set during initialization
     */
    constructor() {
        _initialized = false;
    }
    
    /**
     * @dev Initialize the cap settings
     * @param hardCap Maximum amount of tokens that can be sold
     * @param softCap Minimum amount of tokens that must be sold
     */
    function _initialize(uint256 hardCap, uint256 softCap) internal {
        require(!_initialized, "Cap: already initialized");
        require(hardCap > 0, "Hard cap should be greater than 0");
        require(softCap > 0 && softCap <= hardCap, "Soft cap should be greater than 0 and less than or equal to hard cap");
        
        _hardCap = hardCap;
        _softCap = softCap;
        _softCapReached = false;
        _totalTokensSold = 0;
        _initialized = true;
    }
    
    /**
     * @dev Modifier to check if the hard cap has not been reached
     */
    modifier withinHardCap(uint256 amount) {
        require(_totalTokensSold + amount <= _hardCap, "Hard cap exceeded");
        _;
    }
    
    /**
     * @dev Function to update the total tokens sold and check if soft cap is reached
     * @param amount Amount of tokens to add to the total sold
     * @return Whether the soft cap was just reached with this update
     */
    function _updateTokensSold(uint256 amount) internal returns (bool) {
        _totalTokensSold += amount;
        
        bool justReachedSoftCap = false;
        
        if (!_softCapReached && _totalTokensSold >= _softCap) {
            _softCapReached = true;
            emit SoftCapReached();
            justReachedSoftCap = true;
        }
        
        return justReachedSoftCap;
    }
    
    /**
     * @dev Function to check if adding the specified amount would exceed the hard cap
     * @param amount Amount of tokens to check
     * @return The amount that can be sold without exceeding the hard cap
     */
    function _calculateAllowedAmount(uint256 amount) internal view returns (uint256) {
        if (_totalTokensSold + amount > _hardCap) {
            return _hardCap - _totalTokensSold;
        }
        return amount;
    }
    
    /**
     * @dev Checks whether the hard cap has been reached
     * @return bool Whether the hard cap was reached
     */
    function hardCapReached() public view returns (bool) {
        return _totalTokensSold >= _hardCap;
    }
    
    /**
     * @dev Checks whether the soft cap has been reached
     * @return bool Whether the soft cap was reached
     */
    function isSoftCapReached() public view returns (bool) {
        return _softCapReached || _totalTokensSold >= _softCap;
    }
    
    /**
     * @dev Returns the hard cap value
     * @return The hard cap value
     */
    function getHardCap() public view returns (uint256) {
        return _hardCap;
    }
    
    /**
     * @dev Returns the soft cap value
     * @return The soft cap value
     */
    function getSoftCap() public view returns (uint256) {
        return _softCap;
    }
    
    /**
     * @dev Returns the total tokens sold
     * @return The total tokens sold
     */
    function getTotalTokensSold() public view returns (uint256) {
        return _totalTokensSold;
    }
    
    /**
     * @dev Returns whether the soft cap has been reached
     * @return Whether the soft cap has been reached
     */
    function getSoftCapReached() public view returns (bool) {
        return _softCapReached;
    }
    
    /**
     * @dev Internal function to set the hard cap value
     * @param hardCap New hard cap value
     */
    function _setHardCap(uint256 hardCap) internal {
        require(hardCap > 0, "Hard cap should be greater than 0");
        require(hardCap >= _softCap, "Hard cap should be greater than or equal to soft cap");
        _hardCap = hardCap;
    }
    
    /**
     * @dev Internal function to set the soft cap value
     * @param softCap New soft cap value
     */
    function _setSoftCap(uint256 softCap) internal {
        require(softCap > 0, "Soft cap should be greater than 0");
        require(softCap <= _hardCap, "Soft cap should be less than or equal to hard cap");
        _softCap = softCap;
    }
    
    /**
     * @dev Internal function to set the total tokens sold
     * @param totalSold New total tokens sold value
     */
    function _setTotalTokensSold(uint256 totalSold) internal {
        _totalTokensSold = totalSold;
        
        // Check if setting this value would reach the soft cap
        if (!_softCapReached && _totalTokensSold >= _softCap) {
            _softCapReached = true;
            emit SoftCapReached();
        }
    }
    
    /**
     * @dev Internal function to set soft cap reached status
     * @param reached Whether the soft cap has been reached
     */
    function _setSoftCapReached(bool reached) internal {
        if (!_softCapReached && reached) {
            _softCapReached = true;
            emit SoftCapReached();
        } else {
            _softCapReached = reached;
        }
    }
}
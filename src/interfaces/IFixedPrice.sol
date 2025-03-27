// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IPricingLogic.sol";

/**
 * @title Interface for fixed price STO
 */
interface IFixedPrice is IPricingLogic {
    /**
     * @notice Set the rate for token purchases
     * @param _rate New rate for token purchases (tokens per investment token * 10^18)
     */
    function setRate(uint256 _rate) external;
}
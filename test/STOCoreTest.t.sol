// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {TestERC20} from "../src/test/TestERC20.sol";
import {CappedSTO} from "../src/mixins/CappedSTO2.sol";
import {STOStorage} from "../src/storage/STOStorage.sol";
import {FixedPrice} from "../src/mixins/FixedPrice.sol";
import {Escrow} from "../src/mixins/Escrow.sol";
import {Minting} from "../src/mixins/Minting.sol";
import {Refund} from "../src/mixins/Refund.sol";

contract STOCoreTest is Test {
    // Test tokens
    TestERC20 public securityToken;
    TestERC20 public investmentToken;
    
    // STO contract
    CappedSTO public sto;
    
    // Test accounts
    address public deployer;
    address public investor1;
    address public investor2;
    address public fundsReceiver;
    
    // STO configuration
    uint256 public startTime;
    uint256 public endTime;
    uint256 public hardCap;
    uint256 public softCap;
    uint256 public rate;
    uint256 public minInvestment;
    
    function setUp() public {
        // Setup accounts
        deployer = address(this);
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        fundsReceiver = makeAddr("fundsReceiver");
        
        // Deploy test tokens
        securityToken = new TestERC20(
            "Test Security Token",
            "TST",
            1_000_000 ether, // 1 million tokens
            deployer
        );
        
        investmentToken = new TestERC20(
            "Test USDC",
            "TUSDC",
            10_000_000 ether, // 10 million tokens
            deployer
        );
        
        // Fund investors with investment tokens
        investmentToken.transfer(investor1, 10_000 ether);
        investmentToken.transfer(investor2, 10_000 ether);
        
        // Configure STO parameters
        startTime = block.timestamp;
        endTime = block.timestamp + 1 days;
        hardCap = 100_000 ether; // 100,000 tokens
        softCap = 10_000 ether;  // 10,000 tokens
        rate = 0.1 ether;        // 0.1 security token per 1 investment token
        minInvestment = 100 ether;  // Minimum 100 investment tokens
        
        // Deploy STO
        sto = new CappedSTO(address(securityToken), false); // false = not Rule506c
        
        // Configure STO
        sto.configure(
            startTime,
            endTime,
            hardCap,
            softCap,
            rate,
            payable(fundsReceiver),
            address(investmentToken),
            minInvestment
        );
        
        // Transfer tokens to STO for distribution (for non-Rule506c mode)
        securityToken.transfer(address(sto), hardCap);
        
        // Approve investment tokens for tests
        vm.startPrank(investor1);
        investmentToken.approve(address(sto), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(investor2);
        investmentToken.approve(address(sto), type(uint256).max);
        vm.stopPrank();
    }
    
    // Helper to get investment amount needed for a token amount
    function calculateInvestmentAmount(uint256 tokenAmount) public view returns (uint256) {
        return (tokenAmount * 1 ether) / rate;
    }
    
    // Test basic token purchase
    function testBuyTokens() public {
        uint256 investAmount = 1_000 ether; // 1,000 investment tokens
        uint256 expectedTokens = (investAmount * rate) / 1 ether; // Calculate expected tokens
        
        // Before state
        uint256 investor1BalanceBefore = investmentToken.balanceOf(investor1);
        uint256 stoBalanceBefore = investmentToken.balanceOf(address(sto));
        
        // Buy tokens
        vm.startPrank(investor1);
        sto.buyTokens(investor1, investAmount);
        vm.stopPrank();
        
        // After state
        uint256 investor1BalanceAfter = investmentToken.balanceOf(investor1);
        uint256 stoBalanceAfter = investmentToken.balanceOf(address(sto));
        
        // Assertions
        assertEq(investor1BalanceBefore - investor1BalanceAfter, investAmount, "Incorrect investment token deduction");
        assertEq(stoBalanceAfter - stoBalanceBefore, investAmount, "STO didn't receive investment tokens");
        
        // Check investor is registered
        address[] memory investors = sto.getAllInvestors();
        assertEq(investors.length, 1, "Investor not registered");
        assertEq(investors[0], investor1, "Wrong investor registered");
    }
    
    // Test minimum investment requirement
    function testMinimumInvestment() public {
        uint256 tooSmallAmount = minInvestment - 1 ether;
        
        vm.startPrank(investor1);
        vm.expectRevert(); // Should revert due to minimum investment
        sto.buyTokens(investor1, tooSmallAmount);
        vm.stopPrank();
    }
    
    // Test hard cap enforcement
    function testHardCap() public {
        // Calculate investment needed to reach hard cap
        uint256 investAmount = calculateInvestmentAmount(hardCap);
        
        // First investor buys tokens up to half the cap
        vm.startPrank(investor1);
        sto.buyTokens(investor1, investAmount / 2);
        vm.stopPrank();
        
        // Second investor tries to buy more than remaining cap
        vm.startPrank(investor2);
        sto.buyTokens(investor2, investAmount / 2 + 1 ether);
        vm.stopPrank();
        
        // Check that total tokens sold equals hard cap (not exceeding)
        uint256 tokensSold = sto.getTokensSold();
        assertLe(tokensSold, hardCap, "Hard cap exceeded");
    }
    
    // Test soft cap functionality
    function testSoftCap() public {
        // Calculate investment needed to reach soft cap
        uint256 investAmount = calculateInvestmentAmount(softCap);
        
        // Buy tokens to reach soft cap
        vm.startPrank(investor1);
        sto.buyTokens(investor1, investAmount);
        vm.stopPrank();
        
        // Check soft cap reached
        assertTrue(sto.isSoftCapReached(), "Soft cap not reached");
    }
    
    // Test closing the offering after end time
    function testOfferingEnd() public {
        // Fast forward past end time
        vm.warp(endTime + 1);
        
        // Finalize the offering
        sto.finalize();
        
        // Check STO is closed
        (,,,,,,,,,, bool isClosed) = sto.getSTODetails();
        assertTrue(isClosed, "STO not closed after end time");
    }
    
    // Test token distribution when soft cap is reached
    function testTokenDistribution() public {
        // Calculate investment needed to reach soft cap
        uint256 investAmount = calculateInvestmentAmount(softCap);
        
        // Buy tokens to reach soft cap
        vm.startPrank(investor1);
        sto.buyTokens(investor1, investAmount);
        vm.stopPrank();
        
        // Fast forward past end time
        vm.warp(endTime + 1);
        
        // Finalize the offering
        sto.finalize();
        
        // Check investor received tokens
        uint256 investorTokens = securityToken.balanceOf(investor1);
        assertGt(investorTokens, 0, "Investor didn't receive tokens");
    }
    
    // Test refund when soft cap is not reached
    function testRefund() public {
        // Buy tokens but don't reach soft cap
        uint256 investAmount = calculateInvestmentAmount(softCap / 2);
        
        vm.startPrank(investor1);
        sto.buyTokens(investor1, investAmount);
        vm.stopPrank();
        
        // Fast forward past end time
        vm.warp(endTime + 1);
        
        // Finalize the offering
        sto.finalize();
        
        // Investor claims refund
        uint256 balanceBefore = investmentToken.balanceOf(investor1);
        
        vm.startPrank(investor1);
        sto.claimRefund();
        vm.stopPrank();
        
        uint256 balanceAfter = investmentToken.balanceOf(investor1);
        
        // Check refund was processed
        assertGt(balanceAfter, balanceBefore, "Refund not processed");
    }
    
    // Test multiple investors
    function testMultipleInvestors() public {
        uint256 invest1 = calculateInvestmentAmount(softCap / 2);
        uint256 invest2 = calculateInvestmentAmount(softCap / 2);
        
        // First investor buys tokens
        vm.startPrank(investor1);
        sto.buyTokens(investor1, invest1);
        vm.stopPrank();
        
        // Second investor buys tokens
        vm.startPrank(investor2);
        sto.buyTokens(investor2, invest2);
        vm.stopPrank();
        
        // Check both investors are registered
        address[] memory investors = sto.getAllInvestors();
        assertEq(investors.length, 2, "Not all investors registered");
        
        // Fast forward past end time and finalize
        vm.warp(endTime + 1);
        sto.finalize();
        
        // Check both investors received tokens
        uint256 investor1Tokens = securityToken.balanceOf(investor1);
        uint256 investor2Tokens = securityToken.balanceOf(investor2);
        
        assertGt(investor1Tokens, 0, "Investor 1 didn't receive tokens");
        assertGt(investor2Tokens, 0, "Investor 2 didn't receive tokens");
    }
    
    // Test beneficial investment (someone buys for someone else)
    function testBeneficialInvestment() public {
        // Enable beneficial investments
        sto.changeAllowBeneficialInvestments(true);
        
        uint256 investAmount = 1_000 ether;
        
        // Investor1 buys for Investor2
        vm.startPrank(investor1);
        sto.buyTokens(investor2, investAmount);
        vm.stopPrank();
        
        // Fast forward and finalize
        vm.warp(endTime + 1);
        sto.finalize();
        
        // Check Investor2 received tokens, not Investor1
        uint256 investor1Tokens = securityToken.balanceOf(investor1);
        uint256 investor2Tokens = securityToken.balanceOf(investor2);
        
        assertEq(investor1Tokens, 0, "Investor 1 shouldn't receive tokens");
        assertGt(investor2Tokens, 0, "Investor 2 didn't receive tokens");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LotteryTicket测试合约
 * @dev 对LotteryTicket合约进行全面测试
 */

import {Test} from "forge-std/Test.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";

contract LotteryTicketTest is Test {
    LotteryTicket public lotteryTicket;
    
    address public owner = address(this);
    address public lotteryHook = address(0x1234);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        lotteryTicket = new LotteryTicket();
    }
    
    // 测试构造函数
    function test_Constructor() public {
        assertEq(lotteryTicket.name(), "Lottery Ticket");
        assertEq(lotteryTicket.symbol(), "LTKT");
        assertEq(lotteryTicket.owner(), owner);
        assertEq(lotteryTicket.lotteryHook(), address(0));
    }
    
    // 测试设置彩票钩子地址
    function test_SetLotteryHook() public {
        lotteryTicket.setLotteryHook(lotteryHook);
        assertEq(lotteryTicket.lotteryHook(), lotteryHook);
    }
    
    // 测试非所有者设置彩票钩子地址
    function test_RevertIf_SetLotteryHookNotOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        lotteryTicket.setLotteryHook(lotteryHook);
    }
    
    // 测试铸币功能
    function test_Mint() public {
        // 设置彩票钩子地址
        lotteryTicket.setLotteryHook(lotteryHook);
        
        uint256 amount = 1000;
        
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), amount);
        assertEq(lotteryTicket.totalSupply(), amount);
    }
    
    // 测试非彩票钩子铸币
    function test_RevertIf_MintNotLotteryHook() public {
        vm.expectRevert("Only lottery hook can mint/burn");
        lotteryTicket.mint(user1, 1000);
    }
    
    // 测试销毁功能
    function test_Burn() public {
        // 设置彩票钩子地址
        lotteryTicket.setLotteryHook(lotteryHook);
        
        uint256 amount = 1000;
        
        // 先铸币
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, amount);
        
        // 再销毁
        vm.prank(lotteryHook);
        lotteryTicket.burn(user1, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), 0);
        assertEq(lotteryTicket.totalSupply(), 0);
    }
    
    // 测试非彩票钩子销毁
    function test_RevertIf_BurnNotLotteryHook() public {
        vm.expectRevert("Only lottery hook can mint/burn");
        lotteryTicket.burn(user1, 1000);
    }
    
    // 测试转账功能
    function test_Transfer() public {
        // 设置彩票钩子地址
        lotteryTicket.setLotteryHook(lotteryHook);
        
        uint256 amount = 1000;
        
        // 铸币给用户1
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, amount);
        
        // 用户1转账给用户2
        vm.prank(user1);
        lotteryTicket.transfer(user2, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), 0);
        assertEq(lotteryTicket.balanceOf(user2), amount);
    }
    
    // 测试授权转账
    function test_TransferFrom() public {
        // 设置彩票钩子地址
        lotteryTicket.setLotteryHook(lotteryHook);
        
        uint256 amount = 1000;
        
        // 铸币给用户1
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, amount);
        
        // 用户1授权用户2
        vm.prank(user1);
        lotteryTicket.approve(user2, amount);
        
        // 用户2从用户1转账
        vm.prank(user2);
        lotteryTicket.transferFrom(user1, user2, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), 0);
        assertEq(lotteryTicket.balanceOf(user2), amount);
    }
    
    // 测试铸币事件
    function test_MintEvent() public {
        lotteryTicket.setLotteryHook(lotteryHook);
        
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(0), user1, 1000);
        
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, 1000);
    }
    
    // 测试销毁事件
    function test_BurnEvent() public {
        lotteryTicket.setLotteryHook(lotteryHook);
        
        // 先铸币
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, 1000);
        
        vm.expectEmit(true, false, false, true);
        emit Transfer(user1, address(0), 1000);
        
        vm.prank(lotteryHook);
        lotteryTicket.burn(user1, 1000);
    }
    
    // 测试批量操作
    function test_BatchOperations() public {
        lotteryTicket.setLotteryHook(lotteryHook);
        
        // 批量铸造
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = address(0x3);
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        
        for (uint i = 0; i < recipients.length; i++) {
            vm.prank(lotteryHook);
            lotteryTicket.mint(recipients[i], amounts[i]);
        }
        
        assertEq(lotteryTicket.balanceOf(user1), 100);
        assertEq(lotteryTicket.balanceOf(user2), 200);
        assertEq(lotteryTicket.balanceOf(address(0x3)), 300);
        assertEq(lotteryTicket.totalSupply(), 600);
    }
    
    // 测试零地址处理
    function test_ZeroAddressHandling() public {
        lotteryTicket.setLotteryHook(lotteryHook);
        
        // 铸币到零地址应该失败
        vm.prank(lotteryHook);
        vm.expectRevert();
        lotteryTicket.mint(address(0), 1000);
    }
    
    // 测试溢出保护
    function test_OverflowProtection() public {
        lotteryTicket.setLotteryHook(lotteryHook);
        
        // 测试最大铸币
        vm.prank(lotteryHook);
        lotteryTicket.mint(user1, type(uint256).max);
        
        assertEq(lotteryTicket.balanceOf(user1), type(uint256).max);
        assertEq(lotteryTicket.totalSupply(), type(uint256).max);
    }
}
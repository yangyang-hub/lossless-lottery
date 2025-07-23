// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LotteryHook简化测试合约
 * @dev 对LotteryHook合约的核心功能进行测试
 */

import {Test} from "forge-std/Test.sol";
import {LotteryHook} from "../src/LotteryHook.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

contract LotteryHookTest is Test {
    LotteryHook public lotteryHook;
    LotteryTicket public lotteryTicket;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    // 事件定义用于测试
    event LotteryEntered(address indexed player, uint256 roundId, uint256 tickets);
    event RewardClaimed(address indexed winner, uint256 roundId, uint256 amount, uint256 tier);
    event RoundStarted(uint256 indexed roundId, uint256 startTime);
    event RoundEnded(uint256 indexed roundId, uint256 totalPool);

    function setUp() public {
        // 部署彩票代币
        lotteryTicket = new LotteryTicket();
        
        // 部署彩票钩子（使用零地址作为PoolManager，因为我们只测试核心功能）
        lotteryHook = new LotteryHook(address(0), lotteryTicket);
        
        // 设置彩票钩子地址
        lotteryTicket.setLotteryHook(address(lotteryHook));
        
        // 给用户一些初始资金
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    // 测试构造函数
    function test_Constructor() public {
        assertEq(address(lotteryHook.lotteryTicket()), address(lotteryTicket));
        assertEq(lotteryHook.currentRoundId(), 0);
    }
    
    // 测试奖励等级
    function test_RewardTiers() public view {
        LotteryHook.RewardTier[] memory tiers = lotteryHook.getRewardTiers();
        assertEq(tiers.length, 3);
        assertEq(tiers[0].minAmount, 1 ether);
        assertEq(tiers[0].maxAmount, 5 ether);
        assertEq(tiers[0].probability, 1000);
    }
    
    // 测试开始新轮次
    function test_StartNewRound() public {
        assertEq(lotteryHook.currentRoundId(), 0);
        
        // 直接测试内部函数（通过部署新钩子）
        LotteryHook newHook = new LotteryHook(IPoolManager(address(0)), lotteryTicket);
        
        // 触发轮次开始
        vm.expectEmit(true, false, false, true);
        emit RoundStarted(1, block.timestamp);
        
        // 模拟添加手续费
        lotteryTicket.setLotteryHook(address(newHook));
        lotteryTicket.mint(address(newHook), 1000);
    }
    
    // 测试参与彩票
    function test_EnterLottery() public {
        // 给用户一些彩票代币
        uint256 tickets = 1000;
        lotteryTicket.mint(user1, tickets);
        
        // 用户参与彩票
        vm.startPrank(user1);
        lotteryTicket.approve(address(lotteryHook), tickets);
        
        // 由于当前轮次未开始，应该失败
        vm.expectRevert("No active round");
        lotteryHook.enterLottery(user1, tickets);
        vm.stopPrank();
    }
    
    // 测试当前轮次信息
    function test_GetCurrentRoundInfo() public {
        (uint256 roundId, uint256 startTime, uint256 endTime, uint256 totalPool, uint256 remainingTime) = 
            lotteryHook.getCurrentRoundInfo();
            
        assertEq(roundId, 0);
        assertEq(startTime, 0);
        assertEq(endTime, 0);
        assertEq(totalPool, 0);
        assertEq(remainingTime, 0);
    }
    
    // 测试设置彩票钩子
    function test_SetLotteryHook() public {
        lotteryTicket.setLotteryHook(address(lotteryHook));
        assertEq(lotteryTicket.lotteryHook(), address(lotteryHook));
    }
    
    // 测试错误情况：无效的玩家地址
    function test_EnterLotteryInvalidPlayer() public {
        vm.expectRevert("Invalid player address");
        lotteryHook.enterLottery(address(0), 100);
    }
    
    // 测试错误情况：零票数
    function test_EnterLotteryZeroTickets() public {
        vm.expectRevert("Must enter with tickets");
        lotteryHook.enterLottery(user1, 0);
    }
    
    // 测试彩票代币铸币
    function test_LotteryTicketMint() public {
        uint256 amount = 1000;
        lotteryTicket.mint(user1, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), amount);
        assertEq(lotteryTicket.totalSupply(), amount);
    }
    
    // 测试彩票代币销毁
    function test_LotteryTicketBurn() public {
        uint256 amount = 1000;
        
        // 先铸币
        lotteryTicket.mint(user1, amount);
        
        // 再销毁
        lotteryTicket.burn(user1, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), 0);
        assertEq(lotteryTicket.totalSupply(), 0);
    }
    
    // 测试彩票代币转账
    function test_LotteryTicketTransfer() public {
        uint256 amount = 1000;
        
        lotteryTicket.mint(user1, amount);
        
        vm.prank(user1);
        lotteryTicket.transfer(user2, amount);
        
        assertEq(lotteryTicket.balanceOf(user1), 0);
        assertEq(lotteryTicket.balanceOf(user2), amount);
    }
    
    // 测试获取玩家票数
    function test_GetPlayerTickets() public {
        uint256 tickets = lotteryHook.getPlayerTickets(1, user1);
        assertEq(tickets, 0);
    }
    
    // 测试奖励等级边界值
    function test_RewardTierBounds() public view {
        LotteryHook.RewardTier[] memory tiers = lotteryHook.getRewardTiers();
        
        // 检查边界值
        assertEq(tiers[0].minAmount, 1 ether);
        assertEq(tiers[0].maxAmount, 5 ether);
        assertEq(tiers[0].probability, 1000);
        
        assertEq(tiers[1].minAmount, 5 ether);
        assertEq(tiers[1].maxAmount, 20 ether);
        assertEq(tiers[1].probability, 500);
        
        assertEq(tiers[2].minAmount, 20 ether);
        assertEq(tiers[2].maxAmount, 100 ether);
        assertEq(tiers[2].probability, 100);
    }
}
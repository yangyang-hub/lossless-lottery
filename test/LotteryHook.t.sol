// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LotteryHook测试合约
 * @dev 对LotteryHook合约进行全面测试
 */

import {Test} from "forge-std/Test.sol";
import {LotteryHook} from "../src/LotteryHook.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";
import {IPoolManager,SwapParams} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract LotteryHookTest is Test {
    LotteryHook public lotteryHook;
    LotteryTicket public lotteryTicket;
    MockPoolManager public poolManager;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    // 事件定义用于测试
    event LotteryEntered(address indexed player, uint256 roundId, uint256 tickets);
    event RewardClaimed(address indexed winner, uint256 roundId, uint256 amount, uint256 tier);
    event RoundStarted(uint256 indexed roundId, uint256 startTime);
    event RoundEnded(uint256 indexed roundId, uint256 totalPool);

    function setUp() public {
        // 部署模拟的PoolManager
        poolManager = new MockPoolManager();
        
        // 部署彩票代币
        lotteryTicket = new LotteryTicket();
        
        // 部署彩票钩子
        lotteryHook = new LotteryHook(IPoolManager(address(poolManager)), lotteryTicket);
        
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
        
        // 检查奖励等级
        LotteryHook.RewardTier[] memory tiers = lotteryHook.getRewardTiers();
        assertEq(tiers.length, 3);
        assertEq(tiers[0].minAmount, 1 ether);
        assertEq(tiers[0].maxAmount, 5 ether);
        assertEq(tiers[0].probability, 1000);
    }
    
    // 测试钩子权限
    function test_HookPermissions() public {
        Hooks.Permissions memory permissions = lotteryHook.getHookPermissions();
        assertTrue(permissions.afterSwap);
    }
    
    // 测试添加奖励等级
    function test_AddRewardTier() public {
        // 注意：_addRewardTier是内部函数，需要测试更高层的功能
        LotteryHook.RewardTier[] memory tiers = lotteryHook.getRewardTiers();
        assertEq(tiers.length, 3);
    }
    
    // 测试新轮次开始
    function test_StartNewRound() public {
        assertEq(lotteryHook.currentRoundId(), 0);
        
        // 模拟交易来触发新轮次开始
        PoolKey memory key = _createPoolKey();
        BalanceDelta delta = BalanceDelta.wrap(int256(1 ether));
        
        vm.prank(address(poolManager));
        lotteryHook.afterSwap(address(0), key, _emptySwapParams(), delta, "");
        
        assertEq(lotteryHook.currentRoundId(), 1);
    }
    
    // 测试轮次结束
    function test_EndRound() public {
        // 开始新轮次
        test_StartNewRound();
        
        // 快进时间超过轮次持续时间
        vm.warp(block.timestamp + 8 days);
        
        // 再次触发轮次检查
        PoolKey memory key = _createPoolKey();
        BalanceDelta delta = BalanceDelta.wrap(int256(1 ether));
        
        vm.prank(address(poolManager));
        lotteryHook.afterSwap(address(0), key, _emptySwapParams(), delta, "");
        
        // 验证旧轮次已结束
        (,, uint256 endTime,,) = lotteryHook.getCurrentRoundInfo();
        assertTrue(endTime > 0);
    }
    
    // 测试参与彩票
    function test_EnterLottery() public {
        // 开始新轮次
        test_StartNewRound();
        
        // 给用户一些彩票代币
        uint256 tickets = 1000;
        lotteryTicket.mint(user1, tickets);
        
        // 用户参与彩票
        vm.startPrank(user1);
        lotteryTicket.approve(address(lotteryHook), tickets);
        
        vm.expectEmit(true, true, false, true);
        emit LotteryEntered(user1, 1, tickets);
        
        lotteryHook.enterLottery(user1, tickets);
        vm.stopPrank();
        
        // 验证参与记录
        assertEq(lotteryHook.getPlayerTickets(1, user1), tickets);
    }
    
    // 测试开奖
    function test_DrawWinners() public {
        // 开始新轮次并添加参与者
        test_EnterLottery();
        
        // 添加更多参与者
        lotteryTicket.mint(user2, 500);
        vm.prank(user2);
        lotteryTicket.approve(address(lotteryHook), 500);
        vm.prank(user2);
        lotteryHook.enterLottery(user2, 500);
        
        // 结束轮次
        vm.warp(block.timestamp + 8 days);
        
        // 触发轮次结束
        PoolKey memory key = _createPoolKey();
        BalanceDelta delta = BalanceDelta.wrap(int256(1 ether));
        vm.prank(address(poolManager));
        lotteryHook.afterSwap(address(0), key, _emptySwapParams(), delta, "");
        
        // 开奖
        vm.expectEmit(true, true, false, true);
        emit RewardClaimed(address(0), 1, 0, 0); // 实际中奖者会变化
        
        lotteryHook.drawWinners(1);
    }
    
    // 测试当前轮次信息
    function test_GetCurrentRoundInfo() public {
        test_StartNewRound();
        
        (uint256 roundId, uint256 startTime, uint256 endTime, uint256 totalPool, uint256 remainingTime) = 
            lotteryHook.getCurrentRoundInfo();
            
        assertEq(roundId, 1);
        assertTrue(startTime > 0);
        assertTrue(endTime > startTime);
        assertEq(totalPool, 0); // 初始为0
        assertTrue(remainingTime > 0);
    }
    
    // 测试错误情况：无效的玩家地址
    function test_RevertIf_EnterLotteryInvalidPlayer() public {
        test_StartNewRound();
        vm.expectRevert("Invalid player address");
        lotteryHook.enterLottery(address(0), 100);
    }
    
    // 测试错误情况：零票数
    function test_RevertIf_EnterLotteryZeroTickets() public {
        test_StartNewRound();
        vm.expectRevert("Must enter with tickets");
        lotteryHook.enterLottery(user1, 0);
    }
    
    // 测试错误情况：轮次未开始
    function test_RevertIf_EnterLotteryNoActiveRound() public {
        vm.expectRevert("No active round");
        lotteryHook.enterLottery(user1, 100);
    }
    
    // 测试错误情况：轮次已结束
    function test_RevertIf_EnterLotteryRoundEnded() public {
        test_StartNewRound();
        vm.warp(block.timestamp + 8 days);
        vm.expectRevert("Round ended");
        lotteryHook.enterLottery(user1, 100);
    }
    
    // 测试错误情况：重复开奖
    function test_RevertIf_DrawWinnersAlreadyDrawn() public {
        test_DrawWinners();
        vm.expectRevert("Already drawn");
        lotteryHook.drawWinners(1);
    }
    
    // 测试错误情况：轮次未结束
    function test_RevertIf_DrawWinnersRoundNotEnded() public {
        test_StartNewRound();
        vm.expectRevert("Round not ended");
        lotteryHook.drawWinners(1);
    }
    
    // 辅助函数：创建池子密钥
    function _createPoolKey() internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(0xA)),
            currency1: Currency.wrap(address(0xB)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0x123))
        });
    }
    
    // 辅助函数：创建空的交换参数
    function _emptySwapParams() internal pure returns (SwapParams memory) {
        return SwapParams({
            zeroForOne: true,
            amountSpecified: 0,
            sqrtPriceLimitX96: 0
        });
    }
}

// 模拟PoolManager合约
contract MockPoolManager {
    function afterSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external pure {}
}
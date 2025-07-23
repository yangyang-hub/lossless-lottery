// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LotteryHook - 无损彩票钩子合约
 * @dev 这是一个Uniswap V4钩子合约，通过收集交易费用来创建无损彩票奖池
 * @dev 流动性提供者可以通过交易费用自动获得彩票参与资格，无需额外投入
 * @author 基于Uniswap V4 Hooks架构实现
 */

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager,SwapParams} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {LotteryTicket} from "./LotteryTicket.sol";

contract LotteryHook is BaseHook {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    /**
     * @notice 奖励等级结构体
     * @dev 定义每个奖励等级的参数
     * @param minAmount 该等级的最小奖励金额
     * @param maxAmount 该等级的最大奖励金额
     * @param probability 中奖概率，以基点表示（1 = 0.01%）
     * @param totalTickets 该等级的总票数
     */
    struct RewardTier {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 probability; // basis points (1 = 0.01%)
        uint256 totalTickets;
    }

    /**
     * @notice 彩票轮次结构体
     * @dev 存储每一轮彩票的详细信息
     * @param id 轮次ID
     * @param startTime 轮次开始时间
     * @param endTime 轮次结束时间
     * @param totalPool 奖池总金额
     * @param drawn 是否已开奖的标志，存储随机数以防止重复开奖
     * @param playerTickets 每个地址在该轮次中的票数映射
     * @param participants 该轮次的参与者地址数组
     */
    struct LotteryRound {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPool;
        uint256 drawn;
        mapping(address => uint256) playerTickets;
        address[] participants;
    }

    LotteryTicket public immutable lotteryTicket;
    RewardTier[] public rewardTiers;
    
    /// @notice 存储每个轮次的信息，轮次ID => 轮次详情
    mapping(uint256 => LotteryRound) public rounds;
    
    /// @notice 当前活跃的轮次ID
    uint256 public currentRoundId;
    
    /// @notice 每轮持续时间，默认为7天
    uint256 public constant ROUND_DURATION = 7 days;
    
    /// @notice 票率：每1000 wei费用可获得1张彩票
    uint256 public constant TICKET_RATE = 1000; // 1 ticket per 1000 wei of fees
    
    /// @notice 事件：玩家参与彩票
    /// @param player 参与地址
    /// @param roundId 轮次ID
    /// @param tickets 获得的票数
    event LotteryEntered(address indexed player, uint256 roundId, uint256 tickets);
    
    /// @notice 事件：奖励被领取
    /// @param winner 中奖地址
    /// @param roundId 轮次ID
    /// @param amount 奖励金额
    /// @param tier 奖励等级
    event RewardClaimed(address indexed winner, uint256 roundId, uint256 amount, uint256 tier);
    
    /// @notice 事件：新轮次开始
    /// @param roundId 新轮次ID
    /// @param startTime 开始时间戳
    event RoundStarted(uint256 indexed roundId, uint256 startTime);
    
    /// @notice 事件：轮次结束
    /// @param roundId 轮次ID
    /// @param totalPool 该轮次总奖池
    event RoundEnded(uint256 indexed roundId, uint256 totalPool);

    constructor(IPoolManager _poolManager, LotteryTicket _lotteryTicket) BaseHook(_poolManager) {
        require(address(_poolManager) != address(0), "Invalid pool manager");
        require(address(_lotteryTicket) != address(0), "Invalid lottery ticket");
        
        lotteryTicket = _lotteryTicket;
        
        // 初始化奖励等级并进行验证
        // 小额奖励：10%中奖概率，1-5 ETH奖励范围
        _addRewardTier(1 ether, 5 ether, 1000); // Small: 10% chance
        // 中额奖励：5%中奖概率，5-20 ETH奖励范围
        _addRewardTier(5 ether, 20 ether, 500);  // Medium: 5% chance
        // 大额奖励：1%中奖概率，20-100 ETH奖励范围
        _addRewardTier(20 ether, 100 ether, 100); // Large: 1% chance
    }
    
    /**
     * @notice 添加新的奖励等级
     * @dev 内部函数，用于初始化奖励等级
     * @param minAmount 该等级的最小奖励金额
     * @param maxAmount 该等级的最大奖励金额
     * @param probability 中奖概率，以基点表示（10000 = 100%）
     */
    function _addRewardTier(uint256 minAmount, uint256 maxAmount, uint256 probability) internal {
        require(minAmount > 0, "Min amount must be > 0");
        require(maxAmount > minAmount, "Max amount must be > min");
        require(probability > 0 && probability <= 10000, "Probability must be 1-10000 basis points");
        
        rewardTiers.push(RewardTier(minAmount, maxAmount, probability, 0));
    }

    /**
     * @notice 获取钩子权限配置
     * @dev 定义此钩子需要哪些权限
     * @return Permissions 结构体，包含所有权限设置
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,  // 只在交易后执行，收集费用
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * @notice 交易完成后调用的钩子函数
     * @dev 收集交易费用并转化为彩票参与资格
     * @param key 池子关键信息
     * @param delta 交易导致的余额变化
     * @return 返回钩子选择器和0（无额外费用）
     */
    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        // 计算获得的手续费（简化计算 - 实际计算会更复杂）
        // 根据交易后的余额变化计算手续费
        uint256 feesEarned = uint256(int256(delta.amount0() > 0 ? delta.amount0() : delta.amount1()));
        
        // 如果有手续费收入，添加到彩票奖池
        if (feesEarned > 0) {
            _addToLotteryPool(key, feesEarned);
        }
        
        return (this.afterSwap.selector, 0);
    }

    /**
     * @notice 将手续费添加到彩票奖池
     * @dev 内部函数，处理奖池更新和彩票分配
     * @param key 池子关键信息
     * @param amount 要添加的手续费金额
     */
    function _addToLotteryPool(PoolKey calldata key, uint256 amount) internal {
        // 确保有有效的轮次
        if (rounds[currentRoundId].startTime == 0) {
            _startNewRound();
        }
        
        // 检查轮次是否应该结束
        if (block.timestamp >= rounds[currentRoundId].startTime + ROUND_DURATION) {
            _endRound();
            _startNewRound();
        }
        
        // 将手续费转换为彩票数量，防止溢出
        uint256 tickets;
        unchecked {
            tickets = (amount * TICKET_RATE) / 1 ether;
            require(tickets <= type(uint256).max / 2, "Ticket calculation overflow");
        }
        
        if (tickets > 0) {
            // 向池子管理器铸造彩票（代表流动性提供者）
            lotteryTicket.mint(address(this), tickets);
            
            // 添加到当前轮次
            LotteryRound storage round = rounds[currentRoundId];
            // 如果是首次参与，添加到参与者列表
            if (round.playerTickets[address(this)] == 0) {
                round.participants.push(address(this));
            }
            round.playerTickets[address(this)] += tickets;
            round.totalPool += amount;
            
            emit LotteryEntered(address(this), currentRoundId, tickets);
        }
    }

    /**
     * @notice 开始新一轮彩票
     * @dev 内部函数，初始化新的轮次信息
     */
    function _startNewRound() internal {
        currentRoundId++;
        rounds[currentRoundId].id = currentRoundId;
        rounds[currentRoundId].startTime = block.timestamp;
        
        emit RoundStarted(currentRoundId, block.timestamp);
    }

    /**
     * @notice 结束当前轮次
     * @dev 内部函数，标记轮次结束时间
     */
    function _endRound() internal {
        LotteryRound storage round = rounds[currentRoundId];
        round.endTime = block.timestamp;
        
        emit RoundEnded(currentRoundId, round.totalPool);
    }

    /**
     * @notice 参与彩票游戏
     * @dev 允许用户使用彩票代币参与当前轮次
     * @param player 参与地址
     * @param tickets 使用的彩票数量
     */
    function enterLottery(address player, uint256 tickets) external {
        require(player != address(0), "Invalid player address");
        require(tickets > 0, "Must enter with tickets");
        require(currentRoundId > 0, "No active round");
        
        LotteryRound storage round = rounds[currentRoundId];
        require(block.timestamp < round.startTime + ROUND_DURATION, "Round ended");
        
        // 从玩家转移彩票到此合约
        lotteryTicket.transferFrom(player, address(this), tickets);
        
        // 记录玩家参与
        if (round.playerTickets[player] == 0) {
            round.participants.push(player);
        }
        round.playerTickets[player] += tickets;
        
        emit LotteryEntered(player, currentRoundId, tickets);
    }

    /**
     * @notice 开奖函数，抽取中奖者
     * @dev 任何人都可以调用此函数来为已结束的轮次开奖
     * @param roundId 要开奖的轮次ID
     * @dev 警告：当前使用区块信息作为随机源，不适用于生产环境
     * @dev 生产环境中应使用Chainlink VRF或其他安全的随机数源
     */
    function drawWinners(uint256 roundId) external {
        LotteryRound storage round = rounds[roundId];
        require(round.endTime > 0, "Round not ended");
        require(round.drawn == 0, "Already drawn");
        require(round.totalPool > 0, "Empty pool");
        require(round.participants.length <= 1000, "Too many participants");
        
        // 简化的随机性 - 警告：这不适用于生产环境
        // 在生产环境中，应使用Chainlink VRF或类似的安全随机源
        uint256 random = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            round.participants.length,
            round.totalPool,
            block.number,
            block.coinbase,
            gasleft()
        )));
        
        uint256 remainingPool = round.totalPool;
        uint256 maxTiersPerCall = 10; // 限制gas消耗
        uint256 tiersToProcess = rewardTiers.length > maxTiersPerCall ? maxTiersPerCall : rewardTiers.length;
        
        // 为每个等级抽取中奖者
        for (uint256 i = 0; i < tiersToProcess; i++) {
            if (remainingPool < rewardTiers[i].minAmount) continue;
            
            uint256 tierPrize = _calculateTierPrize(round.totalPool, i);
            if (tierPrize == 0) continue;
            
            address winner = _selectWinner(round, random, i);
            if (winner != address(0)) {
                _distributePrize(winner, tierPrize, i);
                remainingPool -= tierPrize;
            }
            
            // 为下一个等级生成新的随机数
            random = uint256(keccak256(abi.encodePacked(random, i)));
        }
        
        // 记录已开奖状态，存储随机数防止重复开奖
        round.drawn = random;
    }

    /**
     * @notice 计算特定等级的奖励金额
     * @dev 根据奖池总额和等级配置计算实际奖励
     * @param totalPool 该轮次的总奖池
     * @param tierIndex 奖励等级索引
     * @return 该等级的实际奖励金额
     */
    function _calculateTierPrize(uint256 totalPool, uint256 tierIndex) internal view returns (uint256) {
        RewardTier storage tier = rewardTiers[tierIndex];
        uint256 tierAllocation = (totalPool * tier.probability) / 10000;
        
        // 确保奖励金额在配置的范围内
        if (tierAllocation < tier.minAmount) return 0;
        if (tierAllocation > tier.maxAmount) return tier.maxAmount;
        
        return tierAllocation;
    }

    /**
     * @notice 选择中奖者
     * @dev 基于随机数和票数权重选择中奖者
     * @param round 要开奖的轮次信息
     * @param random 随机数种子
     * @param tierIndex 奖励等级索引（用于日志记录）
     * @return 选中的中奖者地址，如果没有有效参与者则返回0地址
     */
    function _selectWinner(
        LotteryRound storage round,
        uint256 random,
        uint256 tierIndex
    ) internal view returns (address) {
        uint256 participantCount = round.participants.length;
        if (participantCount == 0) return address(0);
        
        // 限制gas消耗，最多处理100个参与者
        uint256 maxIterations = participantCount > 100 ? 100 : participantCount;
        
        // 计算总票数
        uint256 totalTickets = 0;
        for (uint256 i = 0; i < maxIterations; i++) {
            totalTickets += round.playerTickets[round.participants[i]];
        }
        
        if (totalTickets == 0) return address(0);
        
        // 选择中奖票号
        uint256 winningTicket = random % totalTickets;
        uint256 cumulative = 0;
        
        // 根据累计票数确定中奖者
        for (uint256 i = 0; i < maxIterations; i++) {
            cumulative += round.playerTickets[round.participants[i]];
            if (winningTicket < cumulative) {
                return round.participants[i];
            }
        }
        
        // 如果没有匹配到（理论上不应该发生），返回最后一个参与者
        return round.participants[maxIterations - 1];
    }

    /**
     * @notice 分发奖励给中奖者
     * @dev 内部函数，处理奖励的转账和事件记录
     * @param winner 中奖者地址
     * @param amount 奖励金额
     * @param tierIndex 奖励等级索引
     */
    function _distributePrize(address winner, uint256 amount, uint256 tierIndex) internal {
        require(winner != address(0), "Invalid winner address");
        require(amount > 0, "Invalid prize amount");
        
        // 在实际实现中，这里会转账实际代币
        // 目前仅记录事件
        emit RewardClaimed(winner, currentRoundId, amount, tierIndex);
    }

    /**
     * @notice 获取当前轮次的详细信息
     * @dev 视图函数，用于查询当前轮次的状态
     * @return roundId 当前轮次ID
     * @return startTime 开始时间戳
     * @return endTime 结束时间戳
     * @return totalPool 当前奖池总额
     * @return remainingTime 剩余时间（秒），如果已结束则为0
     */
    function getCurrentRoundInfo() external view returns (
        uint256 roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 totalPool,
        uint256 remainingTime
    ) {
        LotteryRound storage round = rounds[currentRoundId];
        return (
            currentRoundId,
            round.startTime,
            round.startTime + ROUND_DURATION,
            round.totalPool,
            round.startTime + ROUND_DURATION > block.timestamp ? 
                round.startTime + ROUND_DURATION - block.timestamp : 0
        );
    }

    /**
     * @notice 查询玩家在特定轮次的票数
     * @dev 视图函数，用于查询参与记录
     * @param roundId 轮次ID
     * @param player 玩家地址
     * @return 该玩家在该轮次的票数
     */
    function getPlayerTickets(uint256 roundId, address player) external view returns (uint256) {
        return rounds[roundId].playerTickets[player];
    }

    /**
     * @notice 获取所有奖励等级配置
     * @dev 视图函数，返回完整的奖励等级数组
     * @return RewardTier数组，包含所有奖励等级信息
     */
    function getRewardTiers() external view returns (RewardTier[] memory) {
        return rewardTiers;
    }
}
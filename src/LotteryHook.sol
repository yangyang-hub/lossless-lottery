// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    struct RewardTier {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 probability; // basis points (1 = 0.01%)
        uint256 totalTickets;
    }

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
    
    mapping(uint256 => LotteryRound) public rounds;
    uint256 public currentRoundId;
    uint256 public constant ROUND_DURATION = 7 days;
    uint256 public constant TICKET_RATE = 1000; // 1 ticket per 1000 wei of fees
    
    event LotteryEntered(address indexed player, uint256 roundId, uint256 tickets);
    event RewardClaimed(address indexed winner, uint256 roundId, uint256 amount, uint256 tier);
    event RoundStarted(uint256 indexed roundId, uint256 startTime);
    event RoundEnded(uint256 indexed roundId, uint256 totalPool);

    constructor(IPoolManager _poolManager, LotteryTicket _lotteryTicket) BaseHook(_poolManager) {
        require(address(_poolManager) != address(0), "Invalid pool manager");
        require(address(_lotteryTicket) != address(0), "Invalid lottery ticket");
        
        lotteryTicket = _lotteryTicket;
        
        // Initialize reward tiers with validation
        _addRewardTier(1 ether, 5 ether, 1000); // Small: 10% chance
        _addRewardTier(5 ether, 20 ether, 500);  // Medium: 5% chance
        _addRewardTier(20 ether, 100 ether, 100); // Large: 1% chance
    }
    
    function _addRewardTier(uint256 minAmount, uint256 maxAmount, uint256 probability) internal {
        require(minAmount > 0, "Min amount must be > 0");
        require(maxAmount > minAmount, "Max amount must be > min");
        require(probability > 0 && probability <= 10000, "Probability must be 1-10000 basis points");
        
        rewardTiers.push(RewardTier(minAmount, maxAmount, probability, 0));
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        // Calculate fees earned (simplified - actual fee calculation would be more complex)
        uint256 feesEarned = uint256(int256(delta.amount0() > 0 ? delta.amount0() : delta.amount1()));
        
        if (feesEarned > 0) {
            _addToLotteryPool(key, feesEarned);
        }
        
        return (this.afterSwap.selector, 0);
    }

    function _addToLotteryPool(PoolKey calldata key, uint256 amount) internal {
        // Ensure we have a valid round
        if (rounds[currentRoundId].startTime == 0) {
            _startNewRound();
        }
        
        // Check if round should end
        if (block.timestamp >= rounds[currentRoundId].startTime + ROUND_DURATION) {
            _endRound();
            _startNewRound();
        }
        
        // Convert fees to tickets with overflow protection
        uint256 tickets;
        unchecked {
            tickets = (amount * TICKET_RATE) / 1 ether;
            require(tickets <= type(uint256).max / 2, "Ticket calculation overflow");
        }
        
        if (tickets > 0) {
            // Mint tickets to pool manager (representing the liquidity provider)
            lotteryTicket.mint(address(this), tickets);
            
            // Add to current round
            LotteryRound storage round = rounds[currentRoundId];
            if (round.playerTickets[address(this)] == 0) {
                round.participants.push(address(this));
            }
            round.playerTickets[address(this)] += tickets;
            round.totalPool += amount;
            
            emit LotteryEntered(address(this), currentRoundId, tickets);
        }
    }

    function _startNewRound() internal {
        currentRoundId++;
        rounds[currentRoundId].id = currentRoundId;
        rounds[currentRoundId].startTime = block.timestamp;
        
        emit RoundStarted(currentRoundId, block.timestamp);
    }

    function _endRound() internal {
        LotteryRound storage round = rounds[currentRoundId];
        round.endTime = block.timestamp;
        
        emit RoundEnded(currentRoundId, round.totalPool);
    }

    function enterLottery(address player, uint256 tickets) external {
        require(player != address(0), "Invalid player address");
        require(tickets > 0, "Must enter with tickets");
        require(currentRoundId > 0, "No active round");
        
        LotteryRound storage round = rounds[currentRoundId];
        require(block.timestamp < round.startTime + ROUND_DURATION, "Round ended");
        
        // Transfer tickets from player to this contract
        lotteryTicket.transferFrom(player, address(this), tickets);
        
        // Record player's entry
        if (round.playerTickets[player] == 0) {
            round.participants.push(player);
        }
        round.playerTickets[player] += tickets;
        
        emit LotteryEntered(player, currentRoundId, tickets);
    }

    function drawWinners(uint256 roundId) external {
        LotteryRound storage round = rounds[roundId];
        require(round.endTime > 0, "Round not ended");
        require(round.drawn == 0, "Already drawn");
        require(round.totalPool > 0, "Empty pool");
        require(round.participants.length <= 1000, "Too many participants");
        
        // Simplified randomness - WARNING: This is not secure for production
        // In production, use Chainlink VRF or similar secure randomness source
        uint256 random = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            round.participants.length,
            round.totalPool,
            block.number,
            block.coinbase,
            gasleft()
        )));
        
        uint256 remainingPool = round.totalPool;
        uint256 maxTiersPerCall = 10; // Limit gas consumption
        uint256 tiersToProcess = rewardTiers.length > maxTiersPerCall ? maxTiersPerCall : rewardTiers.length;
        
        // Draw winners for each tier
        for (uint256 i = 0; i < tiersToProcess; i++) {
            if (remainingPool < rewardTiers[i].minAmount) continue;
            
            uint256 tierPrize = _calculateTierPrize(round.totalPool, i);
            if (tierPrize == 0) continue;
            
            address winner = _selectWinner(round, random, i);
            if (winner != address(0)) {
                _distributePrize(winner, tierPrize, i);
                remainingPool -= tierPrize;
            }
            
            random = uint256(keccak256(abi.encodePacked(random, i)));
        }
        
        round.drawn = random;
    }

    function _calculateTierPrize(uint256 totalPool, uint256 tierIndex) internal view returns (uint256) {
        RewardTier storage tier = rewardTiers[tierIndex];
        uint256 tierAllocation = (totalPool * tier.probability) / 10000;
        
        if (tierAllocation < tier.minAmount) return 0;
        if (tierAllocation > tier.maxAmount) return tier.maxAmount;
        
        return tierAllocation;
    }

    function _selectWinner(
        LotteryRound storage round,
        uint256 random,
        uint256 tierIndex
    ) internal view returns (address) {
        uint256 participantCount = round.participants.length;
        if (participantCount == 0) return address(0);
        
        // Limit gas consumption by capping iterations
        uint256 maxIterations = participantCount > 100 ? 100 : participantCount;
        
        uint256 totalTickets = 0;
        for (uint256 i = 0; i < maxIterations; i++) {
            totalTickets += round.playerTickets[round.participants[i]];
        }
        
        if (totalTickets == 0) return address(0);
        
        uint256 winningTicket = random % totalTickets;
        uint256 cumulative = 0;
        
        for (uint256 i = 0; i < maxIterations; i++) {
            cumulative += round.playerTickets[round.participants[i]];
            if (winningTicket < cumulative) {
                return round.participants[i];
            }
        }
        
        return round.participants[maxIterations - 1];
    }

    function _distributePrize(address winner, uint256 amount, uint256 tierIndex) internal {
        require(winner != address(0), "Invalid winner address");
        require(amount > 0, "Invalid prize amount");
        
        // In a real implementation, this would transfer the actual tokens
        // For now, we'll just emit an event
        emit RewardClaimed(winner, currentRoundId, amount, tierIndex);
    }

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

    function getPlayerTickets(uint256 roundId, address player) external view returns (uint256) {
        return rounds[roundId].playerTickets[player];
    }

    function getRewardTiers() external view returns (RewardTier[] memory) {
        return rewardTiers;
    }
}
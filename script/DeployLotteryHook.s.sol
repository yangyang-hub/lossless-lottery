// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {LotteryHook} from "../src/LotteryHook.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";

/**
 * @title DeployLotteryHookScript
 * @dev 部署彩票钩子合约的脚本
 */
contract DeployLotteryHookScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 首先部署彩票代币合约
        console2.log("Deploying LotteryTicket contract...");
        LotteryTicket lotteryTicket = new LotteryTicket();
        console2.log("LotteryTicket deployed to:", address(lotteryTicket));

        // Get PoolManager address based on network
        IPoolManager poolManager = _getPoolManager();
        console2.log("Using PoolManager at:", address(poolManager));

        // Deploy LotteryHook contract
        console2.log("Deploying LotteryHook contract...");
        LotteryHook lotteryHook = new LotteryHook(poolManager, lotteryTicket);
        console2.log("LotteryHook deployed to:", address(lotteryHook));

        // Set lottery hook address on lottery token
        console2.log("Setting lottery hook address...");
        lotteryTicket.setLotteryHook(address(lotteryHook));

        // Verify deployment
        console2.log("Verifying deployment...");
        require(lotteryTicket.lotteryHook() == address(lotteryHook), "Lottery hook address not set correctly");
        require(address(lotteryHook.lotteryTicket()) == address(lotteryTicket), "Lottery ticket address not set correctly");

        console2.log("Deployment complete!");
        console2.log("LotteryTicket address:", address(lotteryTicket));
        console2.log("LotteryHook address:", address(lotteryHook));

        vm.stopBroadcast();
    }

    /**
     * @dev Get PoolManager address based on network
     */
    function _getPoolManager() internal view returns (IPoolManager) {
        uint256 chainId = block.chainid;
        
        // Mainnet
        if (chainId == 1) {
            revert("Mainnet PoolManager address not yet determined");
        }
        // Sepolia testnet
        else if (chainId == 11155111) {
            return IPoolManager(0xe03a1074c86CFeDD5C142C4F04F1a1535E203D5f);
        }
        // Local testnet
        else {
            return IPoolManager(address(0)); // Use zero address for local testing
        }
    }
}
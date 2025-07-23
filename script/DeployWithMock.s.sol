// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {LotteryHook} from "../src/LotteryHook.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";

/**
 * @title DeployWithMockScript
 * @dev Deployment script using mock PoolManager for testing
 */
contract DeployWithMockScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy LotteryTicket contract
        console2.log("Deploying LotteryTicket contract...");
        LotteryTicket lotteryTicket = new LotteryTicket();
        console2.log("LotteryTicket deployed to:", address(lotteryTicket));

        // Use zero address as PoolManager for testing
        IPoolManager poolManager = IPoolManager(address(0));
        console2.log("Using mock PoolManager at:", address(poolManager));

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
}
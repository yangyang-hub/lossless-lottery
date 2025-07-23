// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";

/**
 * @title DeploySimpleScript
 * @dev Simple deployment script for LotteryTicket
 */
contract DeploySimpleScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy LotteryTicket contract
        console2.log("Deploying LotteryTicket contract...");
        LotteryTicket lotteryTicket = new LotteryTicket();
        console2.log("LotteryTicket deployed to:", address(lotteryTicket));

        vm.stopBroadcast();
    }
}
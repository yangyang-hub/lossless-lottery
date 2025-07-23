// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {LotteryTicket} from "../src/LotteryTicket.sol";

/**
 * @title DeployStandaloneScript
 * @dev Simple deployment for LotteryToken only
 */
contract DeployStandaloneScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console2.log("Deploying LotteryTicket contract...");
        LotteryTicket lotteryTicket = new LotteryTicket();
        console2.log("LotteryTicket deployed to:", address(lotteryTicket));

        vm.stopBroadcast();
    }
}
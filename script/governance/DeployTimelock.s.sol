// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {dreTimelockController} from "../../contracts/governance/dreTimelockController.sol";

contract DeployTimelock is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Configuration
        uint256 minDelay = 24 hours; // Can be changed to any value (e.g., 2 days, 7 days)
        
        // Proposers: addresses that can schedule operations
        // Typically a multisig or DAO
        address[] memory proposers = new address[](1);
        proposers[0] = vm.envAddress("PROPOSER_ADDRESS"); // Set in .env
        
        // Executors: addresses that can execute operations
        // Can be same as proposers, or different (e.g., anyone if you want public execution)
        address[] memory executors = new address[](1);
        executors[0] = vm.envAddress("EXECUTOR_ADDRESS"); // Set in .env (can be same as proposer)

        // Deploy timelock
        dreTimelockController timelock = new dreTimelockController(
            minDelay,
            proposers,
            executors
        );

        console.log("dreTimelockController deployed at:", address(timelock));
        console.log("Min delay:", minDelay, "seconds");
        console.log("Min delay:", minDelay / 1 days, "days");
        console.log("Proposers:", proposers.length);
        console.log("Executors:", executors.length);

        vm.stopBroadcast();
    }
}

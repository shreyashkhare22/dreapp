// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {dreTimelockController} from "../../contracts/governance/dreTimelockController.sol";
import {dreUSDManager} from "../../contracts/dreUSDManager.sol";
import {Config} from "../Config.sol";

/**
 * @title TimelockOperations
 * @notice Example script showing how to schedule and execute timelock operations
 * @dev Run with proposer/executor private key set in PRIVATE_KEY env var
 */
contract TimelockOperations is Script {
    dreTimelockController public timelock;
    
    function setUp() public {
        // Set timelock address (deploy first using DeployTimelock.s.sol)
        timelock = dreTimelockController(payable(vm.envAddress("TIMELOCK_ADDRESS")));
    }

    /**
     * @notice Schedule an operation to update the vault address
     */
    function scheduleUpdateVault(address newVault) external {
        uint256 proposerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(proposerKey);

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        dreUSDManager manager = dreUSDManager(cfg.manager);
        
        bytes memory data = abi.encodeWithSelector(
            dreUSDManager.updateVault.selector,
            newVault
        );

        bytes32 operationId = timelock.hashOperation(
            address(manager),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );

        timelock.schedule(
            address(manager),
            0,
            data,
            bytes32(0),                 // no predecessor
            bytes32(0),                 // no salt
            timelock.getMinDelay()      // delay
        );

        console.log("Scheduled operation ID:", vm.toString(operationId));
        console.log("Operation ready at timestamp:", timelock.getTimestamp(operationId));
        console.log("Current timestamp:", block.timestamp);
        console.log("Wait until:", timelock.getTimestamp(operationId));

        vm.stopBroadcast();
    }

    /**
     * @notice Execute a scheduled operation to update vault
     */
    function executeUpdateVault(address newVault) external {
        uint256 executorKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(executorKey);

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        dreUSDManager manager = dreUSDManager(cfg.manager);
        
        bytes memory data = abi.encodeWithSelector(
            dreUSDManager.updateVault.selector,
            newVault
        );

        bytes32 operationId = timelock.hashOperation(
            address(manager),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );

        // Check operation status
        console.log("Operation state:", uint8(timelock.getOperationState(operationId)));
        console.log("Is ready:", timelock.isOperationReady(operationId));
        console.log("Ready timestamp:", timelock.getTimestamp(operationId));
        console.log("Current timestamp:", block.timestamp);

        require(timelock.isOperationReady(operationId), "Operation not ready yet");

        timelock.execute(
            address(manager),
            0,
            data,
            bytes32(0),
            bytes32(0)
        );

        console.log("Operation executed successfully!");

        vm.stopBroadcast();
    }

    /**
     * @notice Schedule updating daily fiat mint cap
     */
    function scheduleSetDailyMintCap(uint256 newCap) external {
        uint256 proposerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(proposerKey);

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        dreUSDManager manager = dreUSDManager(cfg.manager);
        
        bytes memory data = abi.encodeWithSelector(
            dreUSDManager.setDailyFiatMintCap.selector,
            newCap
        );

        timelock.schedule(
            address(manager),
            0,
            data,
            bytes32(0),
            bytes32(0),
            timelock.getMinDelay()
        );

        bytes32 operationId = timelock.hashOperation(
            address(manager), 0, data, bytes32(0), bytes32(0)
        );
        console.log("Scheduled setDailyFiatMintCap operation:", vm.toString(operationId));

        vm.stopBroadcast();
    }

    /**
     * @notice Schedule a batch operation (multiple changes at once)
     */
    function scheduleBatchUpdate(
        address newVault,
        uint256 newMintCap
    ) external {
        uint256 proposerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(proposerKey);

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        dreUSDManager manager = dreUSDManager(cfg.manager);
        
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory payloads = new bytes[](2);

        // Operation 1: Update vault
        targets[0] = address(manager);
        values[0] = 0;
        payloads[0] = abi.encodeWithSelector(
            dreUSDManager.updateVault.selector,
            newVault
        );

        // Operation 2: Update mint cap
        targets[1] = address(manager);
        values[1] = 0;
        payloads[1] = abi.encodeWithSelector(
            dreUSDManager.setDailyFiatMintCap.selector,
            newMintCap
        );

        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            bytes32(0),
            timelock.getMinDelay()
        );

        bytes32 operationId = timelock.hashOperationBatch(
            targets, values, payloads, bytes32(0), bytes32(0)
        );
        console.log("Scheduled batch operation:", vm.toString(operationId));

        vm.stopBroadcast();
    }

    /**
     * @notice Check status of an operation
     */
    function checkOperationStatus(
        address target,
        bytes memory data
    ) external view {
        bytes32 operationId = timelock.hashOperation(
            target, 0, data, bytes32(0), bytes32(0)
        );

        console.log("Operation ID:", vm.toString(operationId));
        console.log("Exists:", timelock.isOperation(operationId));
        console.log("Is pending:", timelock.isOperationPending(operationId));
        console.log("Is ready:", timelock.isOperationReady(operationId));
        console.log("Is done:", timelock.isOperationDone(operationId));
        console.log("Ready timestamp:", timelock.getTimestamp(operationId));
        console.log("Current timestamp:", block.timestamp);
        console.log("State:", uint8(timelock.getOperationState(operationId)));
    }

    /**
     * @notice Cancel a pending operation (requires CANCELLER_ROLE)
     */
    function cancelOperation(
        address target,
        bytes memory data
    ) external {
        uint256 cancellerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(cancellerKey);

        bytes32 operationId = timelock.hashOperation(
            target, 0, data, bytes32(0), bytes32(0)
        );

        timelock.cancel(operationId);
        console.log("Cancelled operation:", vm.toString(operationId));

        vm.stopBroadcast();
    }
}

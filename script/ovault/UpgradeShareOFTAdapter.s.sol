// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { dreShareOFTAdapter } from "../../contracts/ovault/dreShareOFTAdapter.sol";
import { Config } from "../Config.sol";

/**
 * @title UpgradeShareOFTAdapter
 * @notice Upgrades dreShareOFTAdapter implementation on hub chain
 * @dev Deploys new implementation and upgrades the proxy
 */
contract UpgradeShareOFTAdapter is Script {
    function run() external {
        require(
            block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET,
            "ShareOFTAdapter must be upgraded on Base (hub chain)"
        );
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address proxy = cfg.dreShareOFTAdapter;
        address token = cfg.dreUSDs;
        address endpoint = Config.getLzEndpoint(block.chainid);
        require(endpoint != address(0), "LZ_ENDPOINT_V2 not found in config");
        
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy new implementation using standard CREATE (no salt needed)
        // Only the proxy needs to be at the same address
        dreShareOFTAdapter newImplementation = new dreShareOFTAdapter(token, endpoint);
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade the proxy (call upgradeToAndCall on the proxy, which delegates to implementation)
        // Requires owner (held by DEFAULT_ADMIN)
        dreShareOFTAdapter adapter = dreShareOFTAdapter(proxy);
        adapter.upgradeToAndCall(address(newImplementation), "");
        
        console.log("Proxy upgraded to new implementation:", address(newImplementation));
        console.log("Proxy address (unchanged):", proxy);
        vm.stopBroadcast();
    }
}

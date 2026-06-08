// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { dreUSDs } from "../../contracts/dreUSDs.sol";
import { Config } from "../Config.sol";

contract UpgradeDreUSDs is Script {
    function run() external {
        require(
            block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET,
            "dreUSDs must only be upgraded on Base Sepolia or Base Mainnet"
        );
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address proxy = cfg.dreUSDs;
        // LZAddressContext ctx = new LZAddressContext();
        // ctx.setChainByChainId(block.chainid);
        // address endpoint = ctx.getEndpointV2();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy new implementation using standard CREATE (no salt needed)
        // Only the proxy needs to be at the same address across chains
        // dreUSDs newImplementation = new dreUSDs(endpoint);
        dreUSDs newImplementation = new dreUSDs();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade the proxy (call upgradeToAndCall on the proxy, which delegates to implementation)
        // Requires UPGRADER_ROLE (held by DEFAULT_ADMIN)
        dreUSDs vault = dreUSDs(proxy);
        vault.upgradeToAndCall(address(newImplementation), "");
        
        console.log("Proxy upgraded to new implementation:", address(newImplementation));
        console.log("Proxy address (unchanged):", proxy);
        vm.stopBroadcast();
    }
}

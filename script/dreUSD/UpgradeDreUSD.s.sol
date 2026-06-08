// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { dreUSD } from "../../contracts/dreUSD.sol";
import { LZAddressContext } from "lz-address-book/helpers/LZAddressContext.sol";
import { Config } from "../Config.sol";
contract UpgradeDreUSD is Script {
    function run() external {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "UpgradeDreUSD only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address proxy = cfg.dreUSD;
        LZAddressContext ctx = new LZAddressContext();
        ctx.setChainByChainId(block.chainid);
        address endpoint = ctx.getEndpointV2();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy new implementation using standard CREATE (no salt needed)
        // Only the proxy needs to be at the same address across chains
        dreUSD newImplementation = new dreUSD(endpoint);
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade the proxy (call upgradeToAndCall on the proxy, which delegates to implementation)
        // Requires UPGRADER_ROLE (held by DEFAULT_ADMIN)
        dreUSD token = dreUSD(proxy);
        token.upgradeToAndCall(address(newImplementation), "");
        
        console.log("Proxy upgraded to new implementation:", address(newImplementation));
        console.log("Proxy address (unchanged):", proxy);
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { dreShareOFT } from "../../contracts/ovault/dreShareOFT.sol";
import { Config } from "../Config.sol";

/**
 * @title UpgradeShareOFT
 * @notice Upgrades dreShareOFT implementation on spoke chains
 * @dev Deploys new implementation and upgrades the proxy
 */
contract UpgradeShareOFT is Script {
    function run() external {
        require(
            block.chainid != Config.BASE_SEPOLIA && block.chainid != Config.BASE_MAINNET,
            "ShareOFT should NOT be upgraded on Base (hub chain)"
        );

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address proxy = cfg.dreShareOFT;
        address endpoint = Config.getLzEndpoint(block.chainid);
        require(endpoint != address(0), "LZ_ENDPOINT_V2 not found in config");
        address dreUSD = Config.getChainConfig(block.chainid).dreUSD;
        require(dreUSD != address(0), "DREUSD_ADDRESS cannot be zero");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy new implementation using standard CREATE (no salt needed)
        // Only the proxy needs to be at the same address across chains
        dreShareOFT newImplementation = new dreShareOFT(endpoint, dreUSD);
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade the proxy (call upgradeToAndCall on the proxy, which delegates to implementation)
        // Requires owner (held by DEFAULT_ADMIN)
        dreShareOFT shareOFT = dreShareOFT(proxy);
        shareOFT.upgradeToAndCall(address(newImplementation), "");
        
        console.log("Proxy upgraded to new implementation:", address(newImplementation));
        console.log("Proxy address (unchanged):", proxy);
        vm.stopBroadcast();
    }
}

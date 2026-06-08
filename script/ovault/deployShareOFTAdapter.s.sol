// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreShareOFTAdapter } from "../../contracts/ovault/dreShareOFTAdapter.sol";
import { Config } from "../Config.sol";

/**
 * @title DeployShareOFTAdapter
 * @notice Deploys dreShareOFTAdapter on the hub chain (Base) using UUPS proxy pattern
 * @dev This adapter should only be deployed on the hub chain to enable cross-chain share transfers
 * @dev Uses standard CREATE (no CREATE2 needed since it's only deployed on hub chain)
 */
contract DeployShareOFTAdapter is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployShareOFTAdapter only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address token = cfg.dreUSDs;
        address endpoint = Config.getLzEndpoint(block.chainid);
        require(endpoint != address(0), "LZ_ENDPOINT_V2 not found in config");

        address delegate = cfg.defaultAdmin;
        require(delegate != address(0), "DEFAULT_ADMIN cannot be zero address");

        address stuckFundsRecipient = cfg.stuckFundsRecipient;
        require(stuckFundsRecipient != address(0), "STUCK_FUNDS_RECIPIENT_ADDRESS cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be empty");

        vm.startBroadcast(pk);
        _deployShareOFTAdapter(token, endpoint, delegate, stuckFundsRecipient);
        vm.stopBroadcast();
    }

    function _deployShareOFTAdapter(
        address token,
        address endpoint,
        address delegate,
        address stuckFundsRecipient
    ) internal returns (dreShareOFTAdapter adapter) {
        require(
            block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET,
            "ShareOFTAdapter must be deployed on Base (hub chain)"
        );
        
        // Deploy implementation using standard CREATE
        address implementation = _deployShareOFTAdapterImplementation(token, endpoint);
        
        // Deploy proxy using standard CREATE
        address proxyAddr = _deployShareOFTAdapterProxy(implementation, delegate, stuckFundsRecipient);
        adapter = dreShareOFTAdapter(proxyAddr);
    }

    function _deployShareOFTAdapterImplementation(
        address token,
        address endpoint
    ) internal returns (address) {
        // Standard deployment (no CREATE2)
        dreShareOFTAdapter deployedImpl = new dreShareOFTAdapter(token, endpoint);
        address impl = address(deployedImpl);
        console.log("dreShareOFTAdapter implementation deployed at:", impl);
        return impl;
    }

    function _deployShareOFTAdapterProxy(
        address implementation,
        address delegate,
        address stuckFundsRecipient
    ) internal returns (address) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(delegate != address(0), "Delegate cannot be zero address");
        require(stuckFundsRecipient != address(0), "StuckFundsRecipient cannot be zero address");
        
        bytes memory initData = abi.encodeWithSelector(
            dreShareOFTAdapter.initialize.selector,
            delegate,
            stuckFundsRecipient
        );
        
        // Standard deployment (no CREATE2)
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address deployedProxy = address(proxy);
        
        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");
        
        console.log("dreShareOFTAdapter proxy deployed at:", deployedProxy);
        return deployedProxy;
    }
}

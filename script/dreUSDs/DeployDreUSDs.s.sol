// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreUSDs } from "../../contracts/dreUSDs.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";

contract DeployDreUSDs is Script {
    
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployDreUSDs only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address defaultAdmin = cfg.defaultAdmin;
        require(defaultAdmin != address(0), "DefaultAdmin cannot be zero address");
        address dreUSD = cfg.dreUSD;
        require(dreUSD != address(0), "dreUSD cannot be zero address");

        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        dreUSDs vault = _deployDreUSDs(dreUSD, defaultAdmin);
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupDreUSDs(address(vault), cfg.rewardsDistributor, address(0));
        vm.stopBroadcast();
    }

    function _deployDreUSDs(address dreUSD, address defaultAdmin) internal returns (dreUSDs vault) {
        require(
            block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET,
            "dreUSDs must only be deployed on Base Sepolia or Base Mainnet"
        );
        
        require(dreUSD != address(0), "dreUSD cannot be zero address");
        require(defaultAdmin != address(0), "DefaultAdmin cannot be zero address");

        address implementation = _deployDreUSDsImplementation();
        address proxyAddr = _deployDreUSDsProxy(implementation, dreUSD, defaultAdmin);
        vault = dreUSDs(proxyAddr);
    }

    function _deployDreUSDsImplementation() internal returns (address) {
        // Standard deployment (no CREATE2)
        dreUSDs deployedImpl = new dreUSDs();
        address impl = address(deployedImpl);
        console.log("dreUSDs vault implementation deployed at:", impl);
        return impl;
    }

    function _deployDreUSDsProxy(
        address implementation,
        address dreUSD,
        address defaultAdmin
    ) internal returns (address) {
        // Validate inputs
        require(implementation != address(0), "Implementation cannot be zero address");
        require(dreUSD != address(0), "dreUSD cannot be zero address");
        require(defaultAdmin != address(0), "DefaultAdmin cannot be zero address");
        
        bytes memory initData = abi.encodeWithSelector(
            dreUSDs.initialize.selector,
            dreUSD,
            defaultAdmin
        );
        
        // Standard deployment (no CREATE2)
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address deployedProxy = address(proxy);
        
        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");
        
        console.log("dreUSDs vault proxy deployed at:", deployedProxy);
        return deployedProxy;
    }
}

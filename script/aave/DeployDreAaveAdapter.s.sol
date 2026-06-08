// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreAaveAdapter } from "../../contracts/dreAaveAdapter.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";

contract DeployDreAaveAdapter is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployDreAaveAdapter only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address aavePool = cfg.aaveV3Pool;
        address usdc = cfg.usdc;
        address vault = cfg.aaveV3Vault;
        address defaultAdmin = cfg.defaultAdmin;
        address upgrader = cfg.upgrader;

        require(aavePool != address(0), "AAVE_V3_POOL cannot be zero address");
        require(usdc != address(0), "USDC_ADDRESS cannot be zero address");
        require(vault != address(0), "VAULT_ADDRESS cannot be zero address");
        require(defaultAdmin != address(0), "DEFAULT_ADMIN cannot be zero address");
        require(upgrader != address(0), "UPGRADER cannot be zero address");
        require(cfg.manager != address(0), "MANAGER cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be zero");
        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        dreAaveAdapter adapter = _deployDreAaveAdapter(aavePool, usdc, vault, defaultAdmin, upgrader, cfg.manager);
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupAaveV3Adapter(address(adapter), cfg.manager);
        vm.stopBroadcast();
    }

    function _deployDreAaveAdapter(
        address aavePool,
        address usdc,
        address vault,
        address admin,
        address upgrader,
        address manager
    ) internal returns (dreAaveAdapter adapter) {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DreAaveAdapter only on Base Sepolia or Base Mainnet");
        require(aavePool != address(0), "AAVE_V3_POOL cannot be zero address");
        require(usdc != address(0), "USDC cannot be zero address");
        require(vault != address(0), "VAULT cannot be zero address");
        require(admin != address(0), "ADMIN cannot be zero address");
        require(upgrader != address(0), "UPGRADER cannot be zero address");
        require(manager != address(0), "MANAGER cannot be zero address");

        address implementation = _deployDreAaveAdapterImplementation();
        address proxyAddr = _deployProxy(implementation, aavePool, usdc, vault, admin, upgrader, manager);
        adapter = dreAaveAdapter(proxyAddr);
    }

    function _deployDreAaveAdapterImplementation() internal returns (address) {
        dreAaveAdapter deployedImpl = new dreAaveAdapter();
        address impl = address(deployedImpl);
        console.log("dreAaveAdapter implementation deployed at:", impl);
        return impl;
    }

    function _deployProxy(
        address implementation,
        address aavePool,
        address usdc,
        address vault,
        address admin,
        address upgrader,
        address manager
    ) internal returns (address) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(aavePool != address(0), "AAVE_V3_POOL cannot be zero address");
        require(usdc != address(0), "USDC cannot be zero address");
        require(vault != address(0), "VAULT cannot be zero address");
        require(admin != address(0), "ADMIN cannot be zero address");
        require(upgrader != address(0), "UPGRADER cannot be zero address");
        require(manager != address(0), "MANAGER cannot be zero address");

        bytes memory initData = abi.encodeWithSelector(
            dreAaveAdapter.initialize.selector,
            aavePool,
            usdc,
            vault,
            admin,
            upgrader,
            manager
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address deployedProxy = address(proxy);

        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");

        console.log("dreAaveAdapter proxy deployed successfully at:", deployedProxy);
        return deployedProxy;
    }
}

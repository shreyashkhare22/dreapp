// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreRewardsDistributor } from "../../contracts/dreRewardsDistributor.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";

contract DeployDreRewardsDistributor is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployDreRewardsDistributor only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address defaultAdmin = cfg.defaultAdmin;
        address upgraderAddress = cfg.upgrader;
        address pauserAddress = cfg.pauser;
        address dreUSD = cfg.dreUSD;
        address vault = cfg.dreUSDs;

        require(dreUSD != address(0), "DREUSD_ADDRESS cannot be zero address");
        require(vault != address(0), "DREUSDS_ADDRESS cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be zero");
        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        dreRewardsDistributor distributor = _deployDreRewardsDistributor(dreUSD, vault, defaultAdmin, upgraderAddress, pauserAddress);
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupDreRewardsDistributor(address(distributor), cfg.manager);
        vm.stopBroadcast();
    }

    function _deployDreRewardsDistributor(
        address dreUSD,
        address vault,
        address defaultAdmin,
        address upgraderAddress,
        address pauserAddress
    ) internal returns (dreRewardsDistributor distributor) {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DreRewardsDistributor only on Base Sepolia or Base Mainnet");
        require(dreUSD != address(0), "DREUSD_ADDRESS cannot be zero address");
        require(vault != address(0), "DREUSDS_ADDRESS (vault) cannot be zero address");
        require(defaultAdmin != address(0), "DEFAULT_ADMIN cannot be zero address");
        require(upgraderAddress != address(0), "REWARDS_DISTRIBUTOR_UPGRADER cannot be zero address");
        require(pauserAddress != address(0), "REWARDS_DISTRIBUTOR_PAUSER cannot be zero address");

        address implementation = _deployDreRewardsDistributorImplementation(dreUSD, vault);
        address proxyAddr = _deployDreRewardsDistributorProxy(implementation, defaultAdmin, upgraderAddress, pauserAddress);
        distributor = dreRewardsDistributor(proxyAddr);
    }


    function _deployDreRewardsDistributorImplementation(address dreUSD, address vault) internal returns (address) {
        dreRewardsDistributor deployedImpl = new dreRewardsDistributor(dreUSD, vault);
        address impl = address(deployedImpl);
        console.log("Rewards distributor implementation deployed at:", impl);
        return impl;
    }

    function _deployDreRewardsDistributorProxy(
        address implementation,
        address defaultAdmin,
        address upgraderAddress,
        address pauserAddress
    ) internal returns (address) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(defaultAdmin != address(0), "DefaultAdmin cannot be zero address");
        require(upgraderAddress != address(0), "UpgraderAddress cannot be zero address");
        require(pauserAddress != address(0), "PauserAddress cannot be zero address");

        bytes memory initData = abi.encodeWithSelector(
            dreRewardsDistributor.initialize.selector,
            defaultAdmin,
            upgraderAddress,
            pauserAddress
        );
        
        // Deploy proxy using CREATE
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address deployedProxy = address(proxy);
        
        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");
        
        console.log("Rewards distributor proxy deployed successfully at:", deployedProxy);
        return deployedProxy;
    }
}

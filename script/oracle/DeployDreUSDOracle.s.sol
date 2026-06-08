// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreUSDOracle } from "../../contracts/dreUSDOracle.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";
import { MockAggregatorV3 } from "../../contracts/mocks/MockAggregatorV3.sol";

contract DeployDreUSDOracle is Script {
    function run() external virtual {
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address defaultAdmin = cfg.defaultAdmin;
        require(defaultAdmin != address(0), "DEFAULT_ADMIN cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be zero");

        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        dreUSDOracle oracle = _deployDreUSDOracle(cfg);
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupDreUSDOracle(address(oracle), cfg);
        vm.stopBroadcast();
    }

    function _deployDreUSDOracle(Config.ChainConfig memory cfg) internal returns (dreUSDOracle oracle) {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DreUSDOracle only on Base Sepolia or Base Mainnet");
        require(cfg.defaultAdmin != address(0), "DEFAULT_ADMIN cannot be zero address");

        address implementation = _deployDreUSDOracleImplementation();
        address proxyAddr = _deployProxy(implementation, cfg);
        oracle = dreUSDOracle(proxyAddr);
    }

    function _deployDreUSDOracleImplementation() internal returns (address) {
        dreUSDOracle deployedImpl = new dreUSDOracle();
        address impl = address(deployedImpl);
        console.log("dreUSDOracle implementation deployed at:", impl);
        return impl;
    }

    function _deployProxy(address implementation, Config.ChainConfig memory cfg) internal returns (address) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(cfg.defaultAdmin != address(0), "DefaultAdmin cannot be zero address");
        require(cfg.upgrader != address(0), "UPGRADER cannot be zero address");
        require(cfg.moderator != address(0), "MODERATOR cannot be zero address");
        address sequencerUptimeFeed;
        if (block.chainid == Config.BASE_SEPOLIA) {
            MockAggregatorV3 sequencer = new MockAggregatorV3(8, "Sequencer Uptime Feed", 1);
            sequencer.setLatestAnswer(0, block.timestamp - 2 hours);
            sequencerUptimeFeed = address(sequencer);
            console.log("Sequencer uptime feed deployed at:", sequencerUptimeFeed);
        } else {
            sequencerUptimeFeed = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
            console.log("Sequencer uptime feed set to:", sequencerUptimeFeed);
        }

        bytes memory initData = abi.encodeWithSelector(
            dreUSDOracle.initialize.selector,
            cfg.defaultAdmin,
            cfg.upgrader,
            cfg.moderator,
            sequencerUptimeFeed
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address deployedProxy = address(proxy);

        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");

        console.log("dreUSDOracle proxy deployed successfully at:", deployedProxy);
        console.log("Sequencer uptime feed set to:", sequencerUptimeFeed);
        return deployedProxy;
    }
}

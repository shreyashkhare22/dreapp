// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { dreUSD } from "../../contracts/dreUSD.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";

contract DeployDreUSD is Script {
    // Salt for CREATE2 deployment - constant to ensure same addresses across all chains
    // For upgrades: deploy new implementation (standard CREATE) and use UpgradeDreUSD script
    bytes32 constant SALT_IMPL = bytes32(uint256(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef));
    bytes32 constant SALT_PROXY = bytes32(uint256(0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890));

    function run() external virtual {
        address endpoint = Config.getLzEndpoint(block.chainid);
        require(endpoint != address(0), "LZ_ENDPOINT_V2 not found in config");

        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployDreUSD only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address defaultAdmin = cfg.defaultAdmin;
        address upgrader = cfg.upgrader;
        address guardian = cfg.guardian;
        address factory = Config.DEFAULT_CREATE2_FACTORY;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be empty");

        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        dreUSD token = _deployDreUSD(endpoint, defaultAdmin, upgrader, guardian, factory);
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupDreUSD(address(token), cfg.manager, cfg.sanctionsList);
        vm.stopBroadcast();
    }

    /// @param endpoint LayerZero endpoint for the current chain (e.g. Config.getLzEndpoint(block.chainid))
    /// @param defaultAdmin Address to receive DEFAULT_ADMIN_ROLE
    /// @param upgrader Address to receive UPGRADER_ROLE
    /// @param guardian Address to receive GUARDIAN_ROLE
    /// @param factory CREATE2 factory address (e.g. DEFAULT_CREATE2_FACTORY)
    function _deployDreUSD(
        address endpoint,
        address defaultAdmin,
        address upgrader,
        address guardian,
        address factory
    ) internal returns (dreUSD token) {
        require(endpoint != address(0), "endpoint cannot be zero");
        require(defaultAdmin != address(0), "defaultAdmin cannot be zero");
        require(upgrader != address(0), "upgrader cannot be zero");
        require(guardian != address(0), "guardian cannot be zero");

        address implementation = _deployDreUSDImplementation(endpoint, factory);
        address proxyAddr = _deployProxy(implementation, defaultAdmin, upgrader, guardian, factory);
        token = dreUSD(proxyAddr);
    }

    function _deployDreUSDImplementation(address endpoint, address factory) internal returns (address) {
        // Encode constructor parameters and append to creation code
        bytes memory constructorArgs = abi.encode(endpoint);
        bytes memory implBytecode = abi.encodePacked(
            type(dreUSD).creationCode,
            constructorArgs
        );
        bytes32 implBytecodeHash = keccak256(implBytecode);
        address predictedImpl = Create2.computeAddress(SALT_IMPL, implBytecodeHash, factory);
        
        if (predictedImpl.code.length > 0) {
            console.log("Implementation already deployed at:", predictedImpl);
            return predictedImpl;
        } else {
            dreUSD deployedImpl = new dreUSD{salt: SALT_IMPL}(endpoint);
            address impl = address(deployedImpl);
            require(impl == predictedImpl, "Implementation address mismatch");
            console.log("dreUSD token implementation deployed at:", impl);
            return impl;
        }
    }

    function _deployProxy(
        address implementation,
        address defaultAdmin,
        address upgrader,
        address guardian,
        address factory
    ) internal returns (address) {
        // Validate inputs
        require(implementation != address(0), "Implementation cannot be zero address");
        require(defaultAdmin != address(0), "DefaultAdmin cannot be zero address");
        require(upgrader != address(0), "Upgrader cannot be zero address");
        require(guardian != address(0), "Guardian cannot be zero address");

        bytes memory initData = abi.encodeWithSelector(
            dreUSD.initialize.selector,
            defaultAdmin,
            upgrader,
            guardian
        );
        
        // Compute CREATE2 address for proxy
        bytes memory proxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, initData)
        );
        bytes32 proxyBytecodeHash = keccak256(proxyBytecode);
        address predictedProxy = Create2.computeAddress(SALT_PROXY, proxyBytecodeHash, factory);
        
        if (predictedProxy.code.length > 0) {
            console.log("Proxy already deployed at:", predictedProxy);
            console.log("Returning existing proxy address");
            return predictedProxy;
        }
        
        // Deploy proxy using CREATE2
        ERC1967Proxy proxy = new ERC1967Proxy{salt: SALT_PROXY}(implementation, initData);
        address deployedProxy = address(proxy);
        
        require(deployedProxy == predictedProxy, "Proxy address mismatch - CREATE2 factory may not be working");
        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");
        
        console.log("dreUSD token proxy deployed at:", deployedProxy);
        return deployedProxy;
    }
}

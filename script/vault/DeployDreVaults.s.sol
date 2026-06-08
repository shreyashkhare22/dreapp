// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {dreVault} from "../../contracts/dreVault.sol";
import {Config} from "../Config.sol";

/**
 * @title DeployDreVaults
 * @notice Deploys a two-hop dreVault pipeline (hop 1 → hop 2 → corporate wallet).
 * @dev Deploy hop 2 first; hop 1's `forwardVault` is set to the hop 2 contract address.
 *      Token is `Config.usdc`; hop 2 `forwardVault` is `Config.vault2ForwardVault` for the active chain.
 *      Owner is `Config.defaultAdmin` (dre governance multisig).
 *
 * Usage:
 *   forge script script/vault/DeployDreVaults.s.sol:DeployDreVaults \
 *     --rpc-url <RPC> --broadcast
 */
contract DeployDreVaults is Script {
    function run() external {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployDreVaults only on Base");

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address token = cfg.usdc;
        require(token != address(0), "usdc not set in Config for this chain");

        address forwardVault2 = cfg.vault2ForwardVault;
        require(forwardVault2 != address(0), "vault2ForwardVault not set in Config for this chain");

        address owner = cfg.defaultAdmin;
        require(owner != address(0), "defaultAdmin cannot be zero");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        (dreVault hop1, dreVault hop2) = _deployVaults(token, forwardVault2, owner);
        vm.stopBroadcast();

        console.log("token (usdc):", token);
        console.log("owner:", owner);
        console.log("vault2ForwardVault:", forwardVault2);
        console.log("dreVault hop2 (forwards to corporate):", address(hop2));
        console.log("dreVault hop2 forwardVault:", hop2.forwardVault());
        console.log("dreVault hop1 (custodianVault candidate):", address(hop1));
        console.log("dreVault hop1 forwardVault:", hop1.forwardVault());
    }

    function _deployVaults(
        address token,
        address forwardVault2,
        address owner
    ) internal returns (dreVault hop1, dreVault hop2) {
        hop2 = new dreVault(token, forwardVault2, owner);
        require(address(hop2).code.length > 0, "hop2 deployment failed");

        hop1 = new dreVault(token, address(hop2), owner);
        require(address(hop1).code.length > 0, "hop1 deployment failed");
    }
}

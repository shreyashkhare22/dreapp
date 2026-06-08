// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { SanctionsListWhitelistWrapper } from "../../contracts/whitelist/SanctionsListWhitelistWrapper.sol";
import { ISanctionsList } from "../../contracts/interfaces/ISanctionsList.sol";
import { Config } from "../Config.sol";

/**
 * @title DeploySanctionsListWhitelistWrapper
 * @notice Deploys {SanctionsListWhitelistWrapper} on the hub chain (Base) only.
 * @dev Underlying oracle: `Config.sanctionsList` for the chain, unless overridden with env `SANCTIONS_LIST_ORACLE` (e.g. Base Sepolia where config may be zero).
 * @dev Admin: `Config.defaultAdmin`, unless overridden with env `SANCTIONS_WRAPPER_ADMIN`.
 */
contract DeploySanctionsListWhitelistWrapper is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "SanctionsListWhitelistWrapper only on Base (hub)");

        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);

        address underlying = vm.envOr("SANCTIONS_LIST_ORACLE", cfg.sanctionsList);
        require(underlying != address(0), "Underlying sanctions oracle required (Config.sanctionsList or SANCTIONS_LIST_ORACLE)");

        address admin = vm.envOr("SANCTIONS_WRAPPER_ADMIN", cfg.defaultAdmin);
        require(admin != address(0), "Wrapper admin required (Config.defaultAdmin or SANCTIONS_WRAPPER_ADMIN)");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be empty");

        vm.startBroadcast(pk);
        SanctionsListWhitelistWrapper wrapper = new SanctionsListWhitelistWrapper(ISanctionsList(underlying), admin);
        vm.stopBroadcast();

        console.log("SanctionsListWhitelistWrapper deployed at:", address(wrapper));
        console.log("underlying sanctions oracle:", underlying);
        console.log("DEFAULT_ADMIN_ROLE holder:", admin);
    }
}

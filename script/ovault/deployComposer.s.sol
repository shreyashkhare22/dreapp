// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { dreOVaultComposer } from "../../contracts/ovault/dreOVaultComposer.sol";
import { Config } from "../Config.sol";

/**
 * @title DeployComposer
 * @notice Deploys dreOVaultComposer on the hub chain (Base)
 * @dev This composer should only be deployed on the hub chain
 */
contract DeployComposer is Script {

    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployComposer only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address vault = cfg.dreUSDs;
        address assetOFT = cfg.dreUSD;
        address shareOFTAdapter = cfg.dreShareOFTAdapter;
        require(shareOFTAdapter != address(0), "DRE_SHARE_OFT_ADAPTER_ADDRESS cannot be zero address");

        address stuckFundsRecipient = cfg.stuckFundsRecipient;
        require(stuckFundsRecipient != address(0), "STUCK_FUNDS_RECIPIENT_ADDRESS cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be empty");
        vm.startBroadcast(pk);
        _deployComposer(vault, assetOFT, shareOFTAdapter, stuckFundsRecipient);
        vm.stopBroadcast();
    }

    function _deployComposer(address vault, address assetOFT, address shareOFTAdapter, address stuckFundsRecipient) internal returns (dreOVaultComposer composer) {
        require(
            block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET,
            "Composer must be deployed on Base (hub chain)"
        );
        composer = new dreOVaultComposer(vault, assetOFT, shareOFTAdapter, stuckFundsRecipient);
        console.log("dreOVaultComposer deployed at:", address(composer));
    }
}

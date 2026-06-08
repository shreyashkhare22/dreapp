// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "./SetupHelper.s.sol";

/**
 * @title CheckSetup
 * @notice Read-only script that runs SetupHelper.checkSetup using addresses from Config.
 * @dev Same hub chains as SetupDreSystem (Base Sepolia / Base Mainnet). Reverts with a message if any invariant fails.
 * @dev Run example: forge script script/utils/CheckSetup.s.sol:CheckSetup --rpc-url <YOUR_RPC_URL>
 */
contract CheckSetup is Script {
    function run() external view {
        uint256 chainId = block.chainid;
        require(chainId == Config.BASE_SEPOLIA || chainId == Config.BASE_MAINNET, "CheckSetup: only Base Sepolia or Base Mainnet");

        Config.ChainConfig memory cfg = Config.getChainConfig(chainId);

        SetupHelper.checkSetup(
            cfg.dreUSD,
            cfg.dreUSDs,
            cfg.manager,
            cfg.rewardsDistributor,
            cfg.withdrawalNFT,
            cfg.expressWithdrawalNFT,
            cfg.aaveV3Adapter,
            cfg.oracle,
            cfg
        );

        console.log("CheckSetup: all assertions passed");
    }
}

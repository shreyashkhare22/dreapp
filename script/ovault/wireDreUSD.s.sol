// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTWireBase} from "./wire.s.sol";
import {Config} from "../Config.sol";


/// @title wireDreUSD
/// @notice Configure dreUSD OFT across multiple chains using native chain IDs
/// @dev Run this script once per chain (hub or spoke) - it auto-detects via block.chainid.
/// @dev Extend `Config.dreUsdMainnetChainIds`, `Config.isDreUsdMainnetChain`, and `Config.getChainConfig` for new peers.
contract wireDreUSD is OFTWireBase {
    using OptionsBuilder for bytes;

    function run() external {
        (OFTWireBase.ChainConfig[] memory chains, uint256 localIndex) = _buildChainConfigs();
        if (localIndex == type(uint256).max) {
            revert("wireDreUSD: current chain not in dreUSD network");
        }
        wireOFT(chains, "dreUSD");
    }

    /// @dev Build ChainConfig for all dreUSD chains in this network (testnet vs mainnet).
    function _buildChainConfigs() internal view returns (OFTWireBase.ChainConfig[] memory chains, uint256 localIndex) {
        uint256[] memory chainIds = _getDreUSDChainIds();
        chains = new OFTWireBase.ChainConfig[](chainIds.length);
        localIndex = type(uint256).max;

        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 cid = chainIds[i];
            Config.ChainConfig memory cfg = Config.getChainConfig(cid);
            require(cfg.dreUSD != address(0), "wireDreUSD: dreUSD not set in Config for chain");

            if (cid == block.chainid) localIndex = i;

            bool isSpokeWithCompose = (cid == Config.ETH_SEPOLIA);
            chains[i] = OFTWireBase.ChainConfig({
                chainId: cid,
                oapp: cfg.dreUSD,
                confirmations: Config.confirmationsForChain(cid),
                sendOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0),
                sendAndCallOptions: isSpokeWithCompose
                    ? OptionsBuilder.newOptions()
                        .addExecutorLzReceiveOption(80_000, 0)
                        .addExecutorLzComposeOption(0, 400_000, 0)
                    : bytes("")
            });
        }
    }

    /// @notice Chain IDs for this network. Testnet: Base Sepolia + spokes. Mainnet: Base Mainnet + spokes. Add spokes here.
    function _getDreUSDChainIds() internal view returns (uint256[] memory) {
        if (block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.ETH_SEPOLIA) {
            uint256[] memory testnet = new uint256[](2);
            testnet[0] = Config.BASE_SEPOLIA;
            testnet[1] = Config.ETH_SEPOLIA;
            return testnet;
        }
        if (Config.isDreUsdMainnetChain(block.chainid)) {
            return Config.dreUsdMainnetChainIds();
        }
        return new uint256[](0);
    }
}

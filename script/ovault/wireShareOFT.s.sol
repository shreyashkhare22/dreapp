// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTWireBase} from "./wire.s.sol";
import {Config} from "../Config.sol";

/// @title wireShareOFT
/// @notice Configure dreShareOFT (spokes) and dreShareOFTAdapter (hub) across chains
/// @dev Run once per chain. On hub: configures adapter with pathways to each spoke. On spoke: configures dreShareOFT to hub adapter.
contract wireShareOFT is OFTWireBase {
    using OptionsBuilder for bytes;

    function run() external {
        bool isHub = block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET;
        OFTWireBase.ChainConfig[] memory chains = isHub ? _buildHubChains() : _buildSpokeChains();
        wireOFT(chains, isHub ? "dreShareOFTAdapter" : "dreShareOFT");
    }

    /// @dev When on hub: local OApp = adapter; remotes = each spoke's dreShareOFT (adapter must have setPeer(spokeEid, spokeOFT) to receive).
    function _buildHubChains() internal view returns (OFTWireBase.ChainConfig[] memory chains) {
        uint256[] memory spokeChainIds = _getSpokeChainIds();
        chains = new OFTWireBase.ChainConfig[](spokeChainIds.length + 1);

        Config.ChainConfig memory hubCfg = Config.getChainConfig(block.chainid);
        require(hubCfg.dreShareOFTAdapter != address(0), "wireShareOFT: dreShareOFTAdapter not set on hub");
        chains[0] = OFTWireBase.ChainConfig({
            chainId: block.chainid,
            oapp: hubCfg.dreShareOFTAdapter,
            confirmations: Config.confirmationsForChain(block.chainid),
            sendOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0),
            sendAndCallOptions: bytes("")
        });

        for (uint256 i = 0; i < spokeChainIds.length; i++) {
            Config.ChainConfig memory spokeCfg = Config.getChainConfig(spokeChainIds[i]);
            require(spokeCfg.dreShareOFT != address(0), "wireShareOFT: dreShareOFT not set for spoke");
            chains[i + 1] = OFTWireBase.ChainConfig({
                chainId: spokeChainIds[i],
                oapp: spokeCfg.dreShareOFT,
                confirmations: Config.confirmationsForChain(spokeChainIds[i]),
                sendOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0),
                sendAndCallOptions: bytes("")
            });
        }
    }

    /// @dev When on spoke: local OApp = dreShareOFT; single remote = hub adapter.
    function _buildSpokeChains() internal view returns (OFTWireBase.ChainConfig[] memory chains) {
        uint256 hubChainId =
            block.chainid == Config.ETH_SEPOLIA ? Config.BASE_SEPOLIA : Config.BASE_MAINNET;
        Config.ChainConfig memory hubCfg = Config.getChainConfig(hubChainId);
        Config.ChainConfig memory localCfg = Config.getChainConfig(block.chainid);
        require(localCfg.dreShareOFT != address(0), "wireShareOFT: dreShareOFT not set for chain");

        chains = new OFTWireBase.ChainConfig[](2);
        chains[0] = OFTWireBase.ChainConfig({
            chainId: block.chainid,
            oapp: localCfg.dreShareOFT,
            confirmations: Config.confirmationsForChain(block.chainid),
            sendOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0),
            sendAndCallOptions: block.chainid == Config.ETH_SEPOLIA
                ? OptionsBuilder.newOptions()
                    .addExecutorLzReceiveOption(80_000, 0)
                    .addExecutorLzComposeOption(0, 400_000, 0)
                : bytes("")
        });
        chains[1] = OFTWireBase.ChainConfig({
            chainId: hubChainId,
            oapp: hubCfg.dreShareOFTAdapter,
            confirmations: Config.confirmationsForChain(hubChainId),
            sendOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0),
            sendAndCallOptions: bytes("")
        });
    }

    function _getSpokeChainIds() internal view returns (uint256[] memory) {
        if (block.chainid == Config.BASE_SEPOLIA) {
            uint256[] memory ids = new uint256[](1);
            ids[0] = Config.ETH_SEPOLIA;
            return ids;
        }
        if (block.chainid == Config.BASE_MAINNET) {
            return Config.shareOftMainnetSpokeChainIds();
        }
        return new uint256[](0);
    }
}

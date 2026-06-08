// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {dreUSD} from "../../contracts/dreUSD.sol";
import {Config} from "../Config.sol";
import {LZAddressContext} from "lz-address-book/helpers/LZAddressContext.sol";

/// @title depositSpoke
/// @notice Script to deposit dreUSD assets from spoke chain (e.g., Ethereum Sepolia) and receive shares on hub chain (Base Sepolia)
/// @dev Follows LayerZero OVault pattern: https://docs.layerzero.network/v2/developers/evm/ovault/overview#deposit-assets--receive-shares
/// @dev Usage:
///   export PRIVATE_KEY=your_private_key
///   export ASSET_AMOUNT=100000000000000000000  # Amount in wei (100 tokens with 18 decimals)
///   export RECIPIENT=0xRecipientAddress  # Address to receive shares on hub chain (Base Sepolia)
///   export BASE_SEPOLIA_RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY  # Required for quoting composer on hub
///
///   forge script script/ovault/depositSpoke.s.sol:depositSpoke \
///     --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY \
///     --broadcast
contract depositSpoke is Script {
    using OptionsBuilder for bytes;

    // Constants
    uint256 constant SLIPPAGE_BPS = 50; // 0.5% slippage tolerance
    uint128 constant DEFAULT_COMPOSE_GAS = 300_000;
    uint128 constant DEFAULT_LZ_RECEIVE_GAS = 80_000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(pk);
        uint256 assetAmount = vm.envOr("ASSET_AMOUNT", uint256(100000000000000000000));
        address recipient = vm.envOr("RECIPIENT", address(0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05));
        
        require(assetAmount > 0, "Asset amount must be greater than 0");
        require(recipient != address(0), "Recipient address cannot be zero");
        
        uint256 hubChainId = vm.envOr("HUB_CHAIN_ID", uint256(Config.BASE_SEPOLIA));
        uint32 hubEid = _getHubEid(hubChainId);
        Config.ChainConfig memory localCfg = Config.getChainConfig(block.chainid);
        require(localCfg.dreUSD != address(0), "dreUSD not set for this chain in Config");
        dreUSD assetOFT = dreUSD(localCfg.dreUSD);

        console.log("=== Deposit from Spoke Chain ===");
        console.log("Sender:", sender);
        console.log("Amount:", assetAmount);
        console.log("Recipient:", recipient);
        console.log("Hub EID:", hubEid);
        console.log("Balance of sender (dreUSD):", assetOFT.balanceOf(sender));

        require(assetOFT.balanceOf(sender) >= assetAmount, "Insufficient balance");

        (SendParam memory assetSendParam, MessagingFee memory fee) =
            _buildAssetSendAndFee(hubChainId, hubEid, assetAmount, recipient, localCfg);

        // Log fee breakdown
        console.log("=== Fee Breakdown ===");
        console.log("Native fee (wei):", fee.nativeFee);
        console.log("LZ token fee:", fee.lzTokenFee);
        console.log("Compose gas limit:", DEFAULT_COMPOSE_GAS);
        console.log("LZ receive gas limit:", DEFAULT_LZ_RECEIVE_GAS);
        console.log("Note: Fee includes base messaging + lzReceive + lzCompose execution costs");

        vm.startBroadcast(pk);

        assetOFT.send{value: fee.nativeFee}(assetSendParam, fee, sender);

        console.log("=== Success ===");
        vm.stopBroadcast();
    }

    function _getHubEid(uint256 hubChainId) internal returns (uint32) {
        LZAddressContext ctx = new LZAddressContext();
        ctx.setChainByChainId(hubChainId);
        return ctx.getCurrentEID();
    }

    function _buildAssetSendAndFee(
        uint256 hubChainId,
        uint32 hubEid,
        uint256 assetAmount,
        address recipient,
        Config.ChainConfig memory localCfg
    ) internal returns (SendParam memory assetSendParam, MessagingFee memory fee) {
        uint256 expectedShares = _getExpectedShares(hubChainId, assetAmount);
        uint256 minAmountOut = (expectedShares * (10000 - SLIPPAGE_BPS)) / 10000;

        bytes memory composeMsg = _buildComposeMessage(hubEid, recipient, expectedShares, minAmountOut);

        assetSendParam = _buildAssetSendParam(hubChainId, hubEid, assetAmount, composeMsg);
        dreUSD assetOFT = dreUSD(localCfg.dreUSD);
        fee = assetOFT.quoteSend(assetSendParam, false);
    }

    function _getExpectedShares(uint256 hubChainId, uint256 assetAmount) internal returns (uint256) {
        string memory baseRpcUrl = vm.envOr(
            "BASE_SEPOLIA_RPC_URL",
            string("https://base-sepolia.g.alchemy.com/v2/-0PPZAnza5y-okUlI51JJ8FJ7Obey4qT")
        );
        if (hubChainId == Config.BASE_MAINNET) {
            baseRpcUrl = vm.envOr("BASE_MAINNET_RPC_URL", baseRpcUrl);
        }

        console.log("Forking hub to quote composer...");
        uint256 hubFork = vm.createFork(baseRpcUrl);
        vm.selectFork(hubFork);

        Config.ChainConfig memory hubCfg = Config.getChainConfig(hubChainId);
        IERC4626 vault = IERC4626(hubCfg.dreUSDs);
        uint256 expectedShares;
        try vault.previewDeposit(assetAmount) returns (uint256 shares) {
            expectedShares = shares;
            console.log("Expected shares from vault preview (wei):", expectedShares);
            // Log in human-readable format if possible
            if (expectedShares > 0) {
                console.log("Share price ratio:", (assetAmount * 1e18) / expectedShares, "asset per share (scaled)");
            }
        } catch {
            expectedShares = assetAmount;
            console.log("Vault preview failed, using 1:1 estimate");
        }

        vm.selectFork(0); // Switch back to spoke chain
        return expectedShares;
    }

    function _buildComposeMessage(
        uint32 hubEid,
        address recipient,
        uint256 expectedShares,
        uint256 minAmountOut
    ) internal pure returns (bytes memory) {
        SendParam memory shareSendParam = SendParam({
            dstEid: hubEid,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: expectedShares,
            minAmountLD: minAmountOut,
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(DEFAULT_LZ_RECEIVE_GAS, 0),
            composeMsg: "",
            oftCmd: ""
        });

        uint256 lzComposeValue = 0; // Local transfer, no fee needed
        return abi.encode(shareSendParam, lzComposeValue);
    }

    function _buildAssetSendParam(
        uint256 hubChainId,
        uint32 hubEid,
        uint256 assetAmount,
        bytes memory composeMsg
    ) internal pure returns (SendParam memory) {
        Config.ChainConfig memory hubCfg = Config.getChainConfig(hubChainId);
        return SendParam({
            dstEid: hubEid,
            to: bytes32(uint256(uint160(hubCfg.dreOVaultComposer))),
            amountLD: assetAmount,
            minAmountLD: assetAmount,
            extraOptions: OptionsBuilder.newOptions()
                .addExecutorLzReceiveOption(DEFAULT_LZ_RECEIVE_GAS, 0)
                .addExecutorLzComposeOption(0, DEFAULT_COMPOSE_GAS, 0),
            composeMsg: composeMsg,
            oftCmd: ""
        });
    }
}

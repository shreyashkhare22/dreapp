// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IVaultComposerSync} from "@layerzerolabs/ovault-evm/contracts/interfaces/IVaultComposerSync.sol";
import {Config} from "../Config.sol";
import {LZAddressContext} from "lz-address-book/helpers/LZAddressContext.sol";

/// @title depositHubAndSend
/// @notice Script to deposit dreUSD assets on hub chain (Base Sepolia) and send shares to spoke chain
/// @dev This script uses the composer to deposit assets and send shares cross-chain
/// @dev Usage:
///   export PRIVATE_KEY=your_private_key
///   export ASSET_AMOUNT=100000000000000000000  # Amount in wei (100 tokens with 18 decimals)
///   export RECIPIENT=0xRecipientAddress  # Address to receive shares on destination chain
///   export DST_CHAIN_ID=11155111  # Destination chain ID (e.g., Ethereum Sepolia)
///
///   forge script script/ovault/depositHubAndSend.s.sol:depositHubAndSend \
///     --rpc-url https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY \
///     --broadcast
contract depositHubAndSend is Script {
    using OptionsBuilder for bytes;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(pk);
        uint256 assetAmount = vm.envOr("ASSET_AMOUNT", uint256(100000000000000000000));
        address recipient = vm.envOr("RECIPIENT", address(0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05));
        
        require(assetAmount > 0, "Asset amount must be greater than 0");
        require(recipient != address(0), "Recipient address cannot be zero");
        
        // Get destination EID
        LZAddressContext ctx = new LZAddressContext();
        ctx.setChainByChainId(vm.envOr("DST_CHAIN_ID", uint256(11155111)));
        uint32 dstEid = ctx.getCurrentEID();
        
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "depositHubAndSend only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address composerAddress = cfg.dreOVaultComposer;
        IVaultComposerSync composer = IVaultComposerSync(composerAddress);
        IERC20 asset = IERC20(cfg.dreUSD);
        
        console.log("=== Deposit on Hub and Send to Spoke Chain ===");
        console.log("Composer:", composerAddress);
        console.log("Sender:", sender);
        console.log("Amount:", assetAmount);
        console.log("Recipient:", recipient);
        console.log("Destination EID:", dstEid);
        
        vm.startBroadcast(pk);
        
        require(asset.balanceOf(sender) >= assetAmount, "Insufficient balance");
        if (asset.allowance(sender, composerAddress) < assetAmount) {
            asset.approve(composerAddress, type(uint256).max);
        }
        
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: 0,
            minAmountLD: 0,
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0),
            composeMsg: "",
            oftCmd: ""
        });
        
        MessagingFee memory fee = composer.quoteSend(sender, cfg.dreShareOFTAdapter, assetAmount, sendParam);
        console.log("Fee:", fee.nativeFee);
        
        composer.depositAndSend{value: fee.nativeFee}(assetAmount, sendParam, sender);
        
        console.log("=== Success ===");
        vm.stopBroadcast();
    }
}

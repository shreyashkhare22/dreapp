// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {dreUSD} from "../../contracts/dreUSD.sol";
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Config} from "../Config.sol";
import {LZAddressContext} from "lz-address-book/helpers/LZAddressContext.sol";

/// @title SendDreUSD
/// @notice Script to send dreUSD tokens cross-chain via LayerZero
/// @dev Usage:
///   export PRIVATE_KEY=your_private_key
///   export RECIPIENT=0xRecipientAddress
///   export AMOUNT=100000000000000000000  # Amount in wei (100 tokens with 18 decimals)
///   export DST_CHAIN_ID=84532  # Base Sepolia chain ID
///
///   forge script script/SendDreUSD.s.sol \
///     --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY \
///     --broadcast
contract SendDreUSD is Script {
    using OptionsBuilder for bytes;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address recipient = 0xDD6Ac361124b91eBccf29EA28B08d0d0CF073726;
        uint256 amount = 1000000000000000000; // Amount in wei
        uint256 chainId = 11155111; // Destination chain ID
        
        LZAddressContext ctx = new LZAddressContext();
        ctx.setChainByChainId(chainId);
        uint32 dstEid = ctx.getCurrentEID();
        
        
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "SendDreUSD only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address tokenAddress = cfg.dreUSD;
        dreUSD token = dreUSD(tokenAddress);
        
        console.log("=== Sending dreUSD Cross-Chain ===");
        console.log("Token address:", tokenAddress);
        console.log("Recipient:", recipient);
        console.log("Amount:", amount);
        console.log("Destination chain ID:", chainId);
        console.log("Destination EID:", dstEid);
        console.log("");
        
        vm.startBroadcast(pk);
        
        // Prepare SendParam
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(recipient))), // Convert address to bytes32
            amountLD: amount,
            minAmountLD: amount, // No slippage tolerance (set lower if you want to allow slippage)
            extraOptions: OptionsBuilder.newOptions(), // Use default options (enforced options will be applied)
            composeMsg: "", // No compose message
            oftCmd: "" // No OFT command
        });
        
        // Get fee quote
        console.log("Getting fee quote...");
        MessagingFee memory fee = token.quoteSend(sendParam, false);
        console.log("Native fee (wei):", fee.nativeFee);
        console.log("LZ token fee:", fee.lzTokenFee);
        console.log("");
        
        // Check balance
        address sender = vm.addr(pk);
        uint256 balance = token.balanceOf(sender);
        console.log("Sender:", sender);
        console.log("Balance:", balance);
        require(balance >= amount, "Insufficient dreUSD balance");
        console.log("dreUSD balance:", balance);
        
        // Send tokens
        console.log("Sending tokens...");
        (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt) = 
            token.send{value: fee.nativeFee}(sendParam, fee, sender);
        
        console.log("");
        console.log("=== Send Successful ===");
        console.log("GUID:", vm.toString(receipt.guid));
        console.log("Nonce:", receipt.nonce);
        console.log("Amount sent (LD):", oftReceipt.amountSentLD);
        console.log("Amount to receive (LD):", oftReceipt.amountReceivedLD);
        console.log("");
        console.log("Track your transaction at: https://layerzeroscan.com/");
        
        vm.stopBroadcast();
    }
}

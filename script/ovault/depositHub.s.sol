// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Config} from "../Config.sol";

/// @title depositHub
/// @notice Script to deposit dreUSD assets directly into the vault on hub chain (Base Sepolia)
/// @dev This script performs a direct vault deposit without cross-chain operations
/// @dev Usage:
///   export PRIVATE_KEY=your_private_key
///   export ASSET_AMOUNT=100000000000000000000  # Amount in wei (100 tokens with 18 decimals)
///   export RECIPIENT=0xRecipientAddress  # Address to receive shares (defaults to sender if not set)
///
///   forge script script/ovault/depositHub.s.sol:depositHub \
///     --rpc-url https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY \
///     --broadcast
contract depositHub is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(pk);
        
        // Get parameters from environment or use defaults
        uint256 assetAmount = vm.envOr("ASSET_AMOUNT", uint256(13000000000000000000)); // 13 tokens default
        address recipient = vm.envOr("RECIPIENT", sender); // Default to sender if not specified
        
        // Validate inputs
        require(assetAmount > 0, "Asset amount must be greater than 0");
        require(recipient != address(0), "Recipient address cannot be zero");
        
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "depositHub only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address vaultAddress = cfg.dreUSDs;
        address assetAddress = cfg.dreUSD;
        
        IERC4626 vault = IERC4626(vaultAddress);
        IERC20 asset = IERC20(assetAddress);
        
        console.log("=== Direct Deposit on Hub Chain (Base Sepolia) ===");
        console.log("Vault (dreUSDs) address:", vaultAddress);
        console.log("Asset (dreUSD) address:", assetAddress);
        console.log("Sender:", sender);
        console.log("Recipient:", recipient);
        console.log("Asset amount:", assetAmount);
        console.log("");
        
        vm.startBroadcast(pk);
        
        // Check balance and approval
        uint256 balance = asset.balanceOf(sender);
        console.log("dreUSD balance:", balance);
        require(balance >= assetAmount, "Insufficient dreUSD balance");
        
        uint256 allowance = asset.allowance(sender, vaultAddress);
        console.log("Current allowance:", allowance);
        if (allowance < assetAmount) {
            console.log("Approving vault to spend dreUSD...");
            asset.approve(vaultAddress, type(uint256).max);
        }
        
        // Preview shares to be received
        uint256 sharesPreview = vault.previewDeposit(assetAmount);
        console.log("Preview shares to receive:", sharesPreview);
        console.log("");
        
        // Execute direct vault deposit
        console.log("Depositing assets into vault...");
        uint256 sharesReceived = vault.deposit(assetAmount, recipient);
        
        console.log("");
        console.log("=== Deposit Successful ===");
        console.log("Assets deposited:", assetAmount);
        console.log("Shares received:", sharesReceived);
        console.log("Shares recipient:", recipient);
        
        vm.stopBroadcast();
    }
}

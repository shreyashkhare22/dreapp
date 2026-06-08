// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Config} from "../Config.sol";

/// @notice Forge script that prints an EIP-2612 permit signature for a key in env.
///
/// Required environment variable:
/// - PRIVATE_KEY (uint256): signer private key
///
/// Optional environment variables (with defaults):
/// - CHAIN_ID (uint256): chain for config lookup when using defaults (defaults to block.chainid)
/// - PERMIT_TOKEN (address): defaults to Config.getChainConfig(chainId).usdc
/// - PERMIT_SPENDER (address): defaults to Config.getChainConfig(chainId).manager
/// - PERMIT_VALUE (uint256): defaults to 3e6 (3 USDC, 6 decimals)
/// - PERMIT_DEADLINE (uint256): defaults to 2100-01-01 (timestamp 4_102_444_800)
contract PermitSignature is Script {
    function run() external view {
        uint256 chainId = vm.envOr("CHAIN_ID", block.chainid);
        Config.ChainConfig memory cfg = Config.getChainConfig(chainId);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privateKey);
        address token = vm.envOr("PERMIT_TOKEN", cfg.usdc);
        address spender = vm.envOr("PERMIT_SPENDER", cfg.manager);
        uint256 value = vm.envOr("PERMIT_VALUE", uint256(3e6));
        uint256 deadline = vm.envOr("PERMIT_DEADLINE", uint256(4_102_444_800));

        bytes memory permitSig =
            _createPermitSignature(privateKey, token, owner, spender, value, deadline);

        console.log("Permit parameters");
        console.log("owner", owner);
        console.log("token", token);
        console.log("spender", spender);
        console.log("value", value);
        console.log("deadline", deadline);
        console.logBytes(permitSig);
    }

    function _createPermitSignature(
        uint256 privateKey,
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns (bytes memory permitSig) {
        bytes32 hash = MessageHashUtils.toTypedDataHash(
            IERC20Permit(token).DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256(
                        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                    ),
                    owner,
                    spender,
                    value,
                    IERC20Permit(token).nonces(owner),
                    deadline
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        permitSig = abi.encode(deadline, v, r, s);
    }
}
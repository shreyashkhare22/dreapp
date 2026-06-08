// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";
import { IdreUSDManager } from "../../contracts/interfaces/IdreUSDManager.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title MintRewards
 * @notice Script to call mintRewards() on dreUSDManager. Mints dreUSD to the rewards distributor and triggers addRewards().
 * @dev Requires:
 *       - CUSTODIAN_PRIVATE_KEY: key of an address that is a custodian on the manager (signs the FiatMint).
 *       - KEEPER_PRIVATE_KEY: key of an address with KEEPER_ROLE on the manager (broadcasts the tx). Can be same as custodian for dev.
 *       Optional env (defaults in brackets):
 *       - USD_AMOUNT_2DEC: amount in USD with 2 decimals, e.g. 100000 = $1000 (default: 100000)
 *       - VALID_FOR_SECONDS: mint valid for this many seconds from now (default: 3600)
 *       - MINT_REF_STRING: unique string for this mint, e.g. "mint-rewards-2024-01-15-1" (default: keccak256 of timestamp-based ref)
 *       Run on Base Sepolia or Base Mainnet; manager/rewardsDistributor from Config.
 */
contract MintRewards is Script {
    function run() external {
        uint256 chainId = block.chainid;
        require(chainId == Config.BASE_SEPOLIA || chainId == Config.BASE_MAINNET, "MintRewards: only Base Sepolia or Base Mainnet");

        uint256 custodianPk = vm.envOr("CUSTODIAN_PRIVATE_KEY", uint256(0));
        require(custodianPk != 0, "CUSTODIAN_PRIVATE_KEY not set");
        uint256 keeperPk = vm.envOr("KEEPER_PRIVATE_KEY", custodianPk);

        Config.ChainConfig memory cfg = Config.getChainConfig(chainId);
        require(cfg.manager != address(0), "Config: manager not set for this chain");

        address receiver = IdreUSDManager(cfg.manager).dreRewardsDistributor();
        require(receiver != address(0), "dreRewardsDistributor not set on manager");

        uint256 usdAmount2Dec = vm.envOr("USD_AMOUNT_2DEC", uint256(100_000)); // $1000
        uint256 validForSeconds = vm.envOr("VALID_FOR_SECONDS", uint256(3600));
        bytes32 mintRef;
        try vm.envString("MINT_REF_STRING") returns (string memory mintRefStr) {
            mintRef = bytes(mintRefStr).length > 0 ? keccak256(abi.encodePacked(mintRefStr)) : keccak256(abi.encodePacked("mint-rewards-", block.timestamp));
        } catch {
            mintRef = keccak256(abi.encodePacked("mint-rewards-", block.timestamp));
        }
        uint256 validUntil = block.timestamp + validForSeconds;

        IdreUSDManager.FiatMint memory m = IdreUSDManager.FiatMint({
            mintRef: mintRef,
            receiver: receiver,
            usdAmount: usdAmount2Dec,
            validUntil: validUntil,
            chainId: chainId
        });

        // Match manager's _computeFiatMintStructHash: keccak256(abi.encode(a, b, c, d, e, address(manager)))
        bytes32 structHash = keccak256(abi.encode(m.mintRef, m.receiver, m.usdAmount, m.validUntil, m.chainId, cfg.manager));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(custodianPk, ethSignedHash);
        bytes memory custodianSig = abi.encodePacked(r, s, v);

        vm.startBroadcast(keeperPk);
        IdreUSDManager(cfg.manager).mintRewards(m, custodianSig);
        vm.stopBroadcast();

        console.log("mintRewards executed: receiver=%s usdAmount(2dec)=%s mintRef=%s", receiver, usdAmount2Dec, uint256(mintRef));
    }
}

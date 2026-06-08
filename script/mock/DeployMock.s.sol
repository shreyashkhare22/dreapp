// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Config } from "../Config.sol";
import { MockERC20 } from "../../contracts/mocks/MockERC20.sol";
import { MockERC20Permit } from "../../contracts/mocks/MockERC20Permit.sol";
import { AaveV3PoolMock } from "../../contracts/mocks/AaveV3PoolMock.sol";
import { MockAggregatorV3 } from "../../contracts/mocks/MockAggregatorV3.sol";

contract DeployMock is Script {
    uint8 constant USDC_DECIMALS = 6;
    uint256 constant MINT_AMOUNT = 1_000_000 * (10 ** USDC_DECIMALS);

    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployMock: only Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address vault = cfg.aaveV3Vault;
        require(vault != address(0), "DeployMock: AAVE_V3_VAULT not set");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MockERC20 aUsdc = new MockERC20("Aave USDC", "aUSDC", USDC_DECIMALS);
        console.log("aUSDC (MockERC20) deployed at:", address(aUsdc));

        MockERC20Permit usdc = new MockERC20Permit("USD Coin", "USDC", USDC_DECIMALS);
        console.log("USDC (MockERC20Permit) deployed at:", address(usdc));

        AaveV3PoolMock pool = new AaveV3PoolMock(address(usdc), address(aUsdc));
        console.log("AaveV3PoolMock deployed at:", address(pool));

        MockAggregatorV3 usdcFeed = new MockAggregatorV3(8, "USDC / USD", 1);
        console.log("MockAggregatorV3 deployed at:", address(usdcFeed));

        aUsdc.mint(vault, MINT_AMOUNT);
        console.log("Minted", MINT_AMOUNT, "aUSDC to vault");

        aUsdc.approve(address(this), type(uint256).max);
        console.log("Approved adapter to spend vault aUSDC");

        usdc.mint(address(pool), MINT_AMOUNT);
        console.log("Minted", MINT_AMOUNT, "USDC to AaveV3PoolMock");

        MockERC20(cfg.usdc).mint(address(aUsdc), MINT_AMOUNT);
        console.log("Minted USDC toa USDC address for available liquidity");

        vm.stopBroadcast();
    }
}

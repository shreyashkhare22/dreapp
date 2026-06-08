// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreUSDManager } from "../../contracts/dreUSDManager.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";

/**
 * @title DeployDreUSDManager
 * @dev Deploys dreUSDManager as UUPS proxy (CREATE). For Base chains only (Base Sepolia 84532, Base Mainnet 8453).
 *      Requires dreUSD, dreUSDs, USDC, dreUSDOracle, and two dreWithdrawalNFTs (standard and express) to be deployed first.
 *      After deployment: set manager address in chain config; set dreUSDManager on dreUSD, both NFTs, and dreAaveAdapter
 *      via SetupHelper;
 */
contract DeployDreUSDManager is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DreUSDManager only on Base Sepolia or Base Mainnet");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);

        require(cfg.defaultAdmin != address(0), "DEFAULT_ADMIN cannot be zero address");
        require(cfg.dreUSD != address(0), "DREUSD_ADDRESS cannot be zero address");
        require(cfg.dreUSDs != address(0), "DREUSDS_ADDRESS cannot be zero address");
        require(cfg.usdc != address(0), "USDC_ADDRESS cannot be zero address");
        require(cfg.oracle != address(0), "ORACLE_ADDRESS cannot be zero address");
        require(cfg.expressWithdrawalNFT != address(0), "EXPRESS_WITHDRAWAL_NFT_ADDRESS cannot be zero address");
        require(cfg.withdrawalNFT != address(0), "WITHDRAWAL_NFT_ADDRESS cannot be zero address");
        require(cfg.rewardsDistributor != address(0), "DRE_REWARDS_DISTRIBUTOR cannot be zero address");
        require(cfg.aaveV3Adapter != address(0), "AAVE_V3_ADAPTER cannot be zero address");
        require(cfg.expressPaybackAddress != address(0), "EXPRESS_PAYBACK_ADDRESS cannot be zero address");
        require(cfg.expressFeeRecipient != address(0), "EXPRESS_FEE_RECIPIENT cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be zero");
        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        dreUSDManager.RoleAddresses memory roles = dreUSDManager.RoleAddresses({
            defaultAdmin: cfg.defaultAdmin,
            upgrader: cfg.upgrader,
            moderator: cfg.moderator,
            withdrawalConfig: cfg.withdrawalConfig,
            pauser: cfg.pauser,
            keeper: cfg.managerKeeper,
            expressOperator: cfg.managerExpressOperator,
            treasury: cfg.managerTreasury
        });
        dreUSDManager manager = _deployDreUSDManager(
            cfg.dreUSD,
            cfg.dreUSDs,
            cfg.usdc,
            cfg.oracle,
            cfg.expressWithdrawalNFT,
            cfg.withdrawalNFT,
            cfg.expressPaybackAddress,
            cfg.expressFeeRecipient,
            roles
        );
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupDreUSDManager(address(manager), cfg.aaveV3Adapter, cfg);
        vm.stopBroadcast();
    }

    function _deployDreUSDManager(
        address dreUSD_,
        address dreUSDs_,
        address usdc_,
        address oracle_,
        address expressWithdrawalNFT_,
        address withdrawalNFT_,
        address expressPaybackAddress_,
        address expressFeeRecipient_,
        dreUSDManager.RoleAddresses memory roles
    ) internal returns (dreUSDManager manager) {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DreUSDManager only on Base Sepolia or Base Mainnet");

        require(dreUSD_ != address(0), "dreUSD cannot be zero address");
        require(dreUSDs_ != address(0), "dreUSDs cannot be zero address");
        require(usdc_ != address(0), "usdc cannot be zero address");
        require(oracle_ != address(0), "oracle cannot be zero address");
        require(expressWithdrawalNFT_ != address(0), "expressWithdrawalNFT cannot be zero address");
        require(withdrawalNFT_ != address(0), "withdrawalNFT cannot be zero address");
        require(roles.defaultAdmin != address(0), "defaultAdmin cannot be zero address");
        require(expressPaybackAddress_ != address(0), "expressPaybackAddress cannot be zero address");
        require(expressFeeRecipient_ != address(0), "expressFeeRecipient cannot be zero address");
        require(roles.upgrader != address(0), "upgrader cannot be zero address");
        require(roles.moderator != address(0), "moderator cannot be zero address");
        require(roles.withdrawalConfig != address(0), "withdrawalConfig cannot be zero address");
        require(roles.pauser != address(0), "pauser cannot be zero address");
        require(roles.keeper != address(0), "keeper cannot be zero address");
        require(roles.expressOperator != address(0), "expressOperator cannot be zero address");
        require(roles.treasury != address(0), "treasury cannot be zero address");

        address implementation = _deployDreUSDManagerImplementation(
            dreUSD_,
            dreUSDs_,
            usdc_,
            oracle_,
            expressWithdrawalNFT_,
            withdrawalNFT_
        );
        console.log("dreUSDManager implementation deployed at:", implementation);
        address proxyAddr = _deployDreUSDManagerProxy(
            implementation,
            expressPaybackAddress_,
            expressFeeRecipient_,
            roles
        );
        console.log("dreUSDManager proxy deployed at:", proxyAddr);
        manager = dreUSDManager(proxyAddr);
    }

    function _deployDreUSDManagerImplementation(
        address dreUSD_,
        address dreUSDs_,
        address usdc_,
        address oracle_,
        address expressWithdrawalNFT_,
        address withdrawalNFT_
    ) internal returns (address) {
        dreUSDManager impl = new dreUSDManager(
            dreUSD_,
            dreUSDs_,
            usdc_,
            oracle_,
            expressWithdrawalNFT_,
            withdrawalNFT_
        );
        return address(impl);
    }

    function _deployDreUSDManagerProxy(
        address implementation,
        address expressPaybackAddress_,
        address expressFeeRecipient_,
        dreUSDManager.RoleAddresses memory roles
    ) internal returns (address) {
        require(implementation != address(0), "Implementation cannot be zero address");
        require(roles.defaultAdmin != address(0), "defaultAdmin cannot be zero address");
        require(expressPaybackAddress_ != address(0), "expressPaybackAddress cannot be zero address");
        require(expressFeeRecipient_ != address(0), "expressFeeRecipient cannot be zero address");
        require(roles.upgrader != address(0), "upgrader cannot be zero address");
        require(roles.moderator != address(0), "moderator cannot be zero address");
        require(roles.withdrawalConfig != address(0), "withdrawalConfig cannot be zero address");
        require(roles.pauser != address(0), "pauser cannot be zero address");
        require(roles.keeper != address(0), "keeper cannot be zero address");
        require(roles.expressOperator != address(0), "expressOperator cannot be zero address");
        require(roles.treasury != address(0), "treasury cannot be zero address");
        
        bytes memory initData = abi.encodeWithSelector(
            dreUSDManager.initialize.selector,
            expressPaybackAddress_,
            expressFeeRecipient_,
            roles
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address deployedProxy = address(proxy);

        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");
        return deployedProxy;
    }
}

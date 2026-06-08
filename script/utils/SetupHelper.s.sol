// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";
import { dreUSD } from "../../contracts/dreUSD.sol";
import { dreUSDs } from "../../contracts/dreUSDs.sol";
import { dreRewardsDistributor } from "../../contracts/dreRewardsDistributor.sol";
import { dreAaveAdapter } from "../../contracts/dreAaveAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { dreUSDManager } from "../../contracts/dreUSDManager.sol";
import { dreUSDOracle } from "../../contracts/dreUSDOracle.sol";
import { Config } from "../Config.sol";
import { dreWithdrawalNFT } from "../../contracts/dreWithdrawalNFT.sol";

/**
 * @title SetupHelper
 * @dev Helper library for post-deployment setup of contracts.
 */
library SetupHelper {

    /**
     * @dev Sets the sanctions list on dreUSD token (hub: also sets manager).
     * @param dreUSDAddress Address of the dreUSD contract
     * @param managerAddress Address of the manager contract
     * @param sanctionsList Address of the sanctions list contract (no-op if address(0))
     */
    function setupDreUSD(address dreUSDAddress, address managerAddress, address sanctionsList) internal {
        require(dreUSDAddress != address(0), "DREUSD address cannot be zero");
        require(managerAddress != address(0), "Manager address cannot be zero");

        dreUSD token = dreUSD(dreUSDAddress);
        if (sanctionsList != address(0)) {
            console.log("Setting sanctions list on dreUSD");
            token.setSanctionsList(sanctionsList);
        }
        if (token.dreUSDManager() != managerAddress) {
            token.setDreUSDManager(managerAddress);
        }
    }

    /**
     * @dev Spoke-only: sets the sanctions list on dreUSD (no manager on spoke; mint/burn via OFT).
     * @param dreUSDAddress Address of the dreUSD contract on the spoke
     * @param sanctionsList Address of the sanctions list contract (no-op if address(0))
     */
    function setupDreUSDSpoke(address dreUSDAddress, address sanctionsList) internal {
        require(dreUSDAddress != address(0), "DREUSD address cannot be zero");
        if (sanctionsList == address(0)) return;
        dreUSD token = dreUSD(dreUSDAddress);
        token.setSanctionsList(sanctionsList);
    }

    /**
     * @dev Sets the rewards distributor and share OFT adapter for the dreUSDs (hub only for adapter).
     * @param dreUSDsAddress Address of the dreUSDs contract
     * @param rewardsDistributor Address of the dreRewardsDistributor contract
     * @param shareOFTAdapter Address of the share OFT adapter (hub only; pass address(0) on spoke)
     */
    function setupDreUSDs(address dreUSDsAddress, address rewardsDistributor, address shareOFTAdapter) internal {
        require(dreUSDsAddress != address(0), "DREUSDs address cannot be zero");
        require(rewardsDistributor != address(0), "Rewards distributor address cannot be zero");

        dreUSDs vault = dreUSDs(dreUSDsAddress);
        if (vault.rewardsDistributor() != rewardsDistributor) {
            console.log("Setting rewards distributor on dreUSDs");
            vault.setRewardsDistributor(rewardsDistributor);
        }
        if (shareOFTAdapter != address(0) && vault.shareOFTAdapter() != shareOFTAdapter) {
            vault.setShareOFTAdapter(shareOFTAdapter);
        }
    }

    /**
     * @dev Sets the MODERATOR_ROLE on the dreRewardsDistributor to the manager
     * @param rewardsDistributor Address of the dreRewardsDistributor contract
     * @param managerAddress Address of the manager contract
     */
     function setupDreRewardsDistributor(address rewardsDistributor, address managerAddress) internal {
        require(rewardsDistributor != address(0), "Rewards distributor address cannot be zero");
        require(managerAddress != address(0), "Manager address cannot be zero");

        dreRewardsDistributor distributor = dreRewardsDistributor(rewardsDistributor);
        bytes32 moderatorRole = distributor.MODERATOR_ROLE();
        
        if (!distributor.hasRole(moderatorRole, managerAddress)) {
            console.log("Granting MODERATOR_ROLE on dreRewardsDistributor to manager");
            distributor.grantRole(moderatorRole, managerAddress);
        }

        uint256 rewards = distributor.rewards();
        if (rewards == 0) {
            console.log("[FAIL] No rewards in dreRewardsDistributor");
        } 
    }

    /**
     * @dev Sets dreUSDManager on both withdrawal NFTs (standard and express); only the manager may call mint() and burn()
     * @param withdrawalNFTAddress Address of the withdrawal NFT contract
     * @param expressWithdrawalNFTAddress Address of the express withdrawal NFT contract
     * @param managerAddress Address of the manager contract
     */
    function setupWithdrawalNFTs(address withdrawalNFTAddress, address expressWithdrawalNFTAddress, address managerAddress) internal {
        require(withdrawalNFTAddress != address(0), "WITHDRAWAL_NFT_ADDRESS cannot be zero");
        require(expressWithdrawalNFTAddress != address(0), "EXPRESS_WITHDRAWAL_NFT_ADDRESS cannot be zero");
        require(managerAddress != address(0), "MANAGER cannot be zero");

        dreWithdrawalNFT standardNFT = dreWithdrawalNFT(withdrawalNFTAddress);
        dreWithdrawalNFT expressNFT = dreWithdrawalNFT(expressWithdrawalNFTAddress);
        if (standardNFT.dreUSDManager() != managerAddress) {
            standardNFT.setDreUSDManager(managerAddress);
        }
        if (expressNFT.dreUSDManager() != managerAddress) {
            expressNFT.setDreUSDManager(managerAddress);
        }
    }

    /**
     * @dev Sets dreUSDManager on the AAVE adapter (only the manager may call withdraw())
     *      and checks if the adapter has allowance on the vault to spend aUSDC
     * @param aaveV3AdapterAddress Address of the AAVE adapter contract
     * @param managerAddress Address of the manager contract
     */
    function setupAaveV3Adapter(address aaveV3AdapterAddress, address managerAddress) internal {
        require(aaveV3AdapterAddress != address(0), "AAVE_V3_ADAPTER cannot be zero");
        require(managerAddress != address(0), "MANAGER cannot be zero");

        dreAaveAdapter adapter = dreAaveAdapter(payable(aaveV3AdapterAddress));
        if (adapter.dreUSDManager() != managerAddress) {
            adapter.setDreUSDManager(managerAddress);
        }
        
        uint256 allowance = IERC20(adapter.aUsdc()).allowance(adapter.vault(), aaveV3AdapterAddress);
        if (allowance == 0) {
            console.log("[FAIL] AAVE adapter must have allowance on vault to spend aUSDC");
        }
    }

    /**
     * @dev Sets the roles in the dreUSDManager using chain-specific config
     * @param managerAddress Address of the manager contract
     * @param aaveAdapterAddress Address of the AAVE adapter contract
     * @param cfg Chain config (e.g. Config.getChainConfig(block.chainid))
     */
    function setupDreUSDManager(address managerAddress, address aaveAdapterAddress, Config.ChainConfig memory cfg) internal {
        require(managerAddress != address(0), "MANAGER cannot be zero");
        require(aaveAdapterAddress != address(0), "aaveAdapterAddress cannot be zero");
        require(cfg.custodianVault != address(0), "CUSTODIAN_VAULT cannot be zero");
        require(cfg.dailyFiatMintCapUsd != 0, "DAILY_FIAT_MINT_CAP_USD cannot be zero");
        require(cfg.usdc != address(0), "USDC_ADDRESS cannot be zero");

        dreUSDManager manager = dreUSDManager(payable(managerAddress));
        if (manager.custodianVault() != cfg.custodianVault) {
            console.log("Updating custodian vault on dreUSDManager");
            manager.updateVault(cfg.custodianVault);
        }
        if (manager.withdrawalVaultAdapter() != aaveAdapterAddress) {
            console.log("Updating withdrawal vault adapter on dreUSDManager");
            manager.updateVaultAdapter(aaveAdapterAddress);
        }
        if (manager.dailyFiatMintCapUsd() != cfg.dailyFiatMintCapUsd) {
            console.log("Setting daily fiat mint cap on dreUSDManager");
            manager.setDailyFiatMintCap(cfg.dailyFiatMintCapUsd);
        }
        if (!manager.allowed(cfg.usdc)) {
            console.log("Updating allowed list on dreUSDManager for USDC");
            manager.updateAllowedList(cfg.usdc, true);
        }
        if (cfg.usdt != address(0) && !manager.allowed(cfg.usdt)) {
            console.log("Updating allowed list on dreUSDManager for USDT");
            manager.updateAllowedList(cfg.usdt, true);
        }
        if (!manager.hasRole(manager.EXPRESS_OPERATOR_ROLE(), cfg.managerExpressOperator)) {
            console.log("Granting EXPRESS_OPERATOR_ROLE on dreUSDManager");
            manager.grantRole(manager.EXPRESS_OPERATOR_ROLE(), cfg.managerExpressOperator);
        }
        if (!manager.hasRole(manager.TREASURY_ROLE(), cfg.managerTreasury)) {
            console.log("Granting TREASURY_ROLE on dreUSDManager");
            manager.grantRole(manager.TREASURY_ROLE(), cfg.managerTreasury);
        }
        if (!manager.hasRole(manager.KEEPER_ROLE(), cfg.managerKeeper)) {
            console.log("Granting KEEPER_ROLE on dreUSDManager");
            manager.grantRole(manager.KEEPER_ROLE(), cfg.managerKeeper);
        }
        if (!manager.custodians(cfg.custodian)) {
            console.log("Updating custodian list on dreUSDManager");
            manager.updateCustodianList(cfg.custodian, true);
        }

        if (block.chainid == Config.BASE_SEPOLIA) {
            if (manager.withdrawalWaitingTime() != 1 days) {
                console.log("Updating withdrawal waiting time on dreUSDManager for test chain");
                manager.updateWithdrawal(1 days);
            }
            
        }
    }

    /**
     * @dev Sets oracle feeds on dreUSDOracle using chain-specific config
     * @param oracleAddress Address of the dreUSDOracle contract
     * @param cfg Chain config (e.g. Config.getChainConfig(block.chainid))
     */
    function setupDreUSDOracle(address oracleAddress, Config.ChainConfig memory cfg) internal {
        require(oracleAddress != address(0), "ORACLE_ADDRESS cannot be zero");
        require(cfg.usdc != address(0), "USDC_ADDRESS cannot be zero");
        require(cfg.stalenessThresholdSeconds != 0, "STALENESS_THRESHOLD_SECONDS cannot be zero");
        require(cfg.usdcOracleFeed != address(0), "USDC_ORACLE_FEED cannot be zero");

        dreUSDOracle oracle = dreUSDOracle(oracleAddress);
        if (oracle.oracles(cfg.usdc) != cfg.usdcOracleFeed) {
            console.log("Setting USDC oracle on dreUSDOracle");
            oracle.setOracle(cfg.usdc, cfg.usdcOracleFeed, cfg.stalenessThresholdSeconds);
        }
        if (cfg.usdt != address(0) && cfg.usdtOracleFeed != address(0) && oracle.oracles(cfg.usdt) != cfg.usdtOracleFeed) {
            console.log("Setting USDT oracle on dreUSDOracle");
            oracle.setOracle(cfg.usdt, cfg.usdtOracleFeed, cfg.stalenessThresholdSeconds);
        }
        if (block.chainid == Config.BASE_SEPOLIA) {
            if (oracle.gracePeriod() != 60) {
                console.log("Setting grace period on dreUSDOracle for test chain");
                oracle.setGracePeriod(60);
            }
        }
    }

    /**
     * @dev Checks if the contracts are setup correctly
     * @param dreUSDAddress Address of the dreUSD contract
     * @param dreUSDsAddress Address of the dreUSDs contract
     * @param managerAddress Address of the manager contract
     * @param rewardsDistributorAddress Address of the dreRewardsDistributor contract
     * @param standardNFTAddress Address of the dreWithdrawalNFT contract
     * @param expressNFTAddress Address of the dreWithdrawalNFT contract
     * @param aaveAdapterAddress Address of the dreAaveAdapter contract
     * @param oracleAddress Address of the dreUSDOracle contract
     * @param cfg Chain config (for role addresses, aaveV3Vault must match adapter vault and approve aUSDC to the adapter)
     */
    function checkSetup(
        address dreUSDAddress,
        address dreUSDsAddress,
        address managerAddress,
        address rewardsDistributorAddress,
        address standardNFTAddress,
        address expressNFTAddress,
        address aaveAdapterAddress,
        address oracleAddress,
        Config.ChainConfig memory cfg
    ) internal view {
        require(dreUSDAddress != address(0), "DREUSD cannot be zero");
        require(dreUSDsAddress != address(0), "DREUSDs cannot be zero");
        require(rewardsDistributorAddress != address(0), "DRE_REWARDS_DISTRIBUTOR cannot be zero");
        require(standardNFTAddress != address(0), "STANDARD_NFT cannot be zero");
        require(expressNFTAddress != address(0), "EXPRESS_NFT cannot be zero");
        require(managerAddress != address(0), "Manager address cannot be zero");
        require(aaveAdapterAddress != address(0), "AAVE_ADAPTER cannot be zero");
        require(oracleAddress != address(0), "ORACLE cannot be zero");

        dreUSD token = dreUSD(dreUSDAddress);
        require(token.hasRole(token.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on dreUSD");
        require(token.hasRole(token.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on dreUSD");
        require(token.hasRole(token.GUARDIAN_ROLE(), cfg.guardian), "GUARDIAN_ROLE not granted on dreUSD");
        require(token.dreUSDManager() == managerAddress, "dreUSDManager not set on dreUSD to Manager");

        dreUSDs vault = dreUSDs(dreUSDsAddress);
        require(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on dreUSDs");
        require(vault.hasRole(vault.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on dreUSDs");
        require(vault.hasRole(vault.PAUSER_ROLE(), cfg.pauser), "PAUSER_ROLE not granted on dreUSDs");

        dreRewardsDistributor distributor = dreRewardsDistributor(rewardsDistributorAddress);
        require(distributor.hasRole(distributor.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on dreRewardsDistributor");
        require(distributor.hasRole(distributor.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on dreRewardsDistributor");
        require(distributor.hasRole(distributor.PAUSER_ROLE(), cfg.pauser), "PAUSER_ROLE not granted on dreRewardsDistributor");
        require(distributor.hasRole(distributor.MODERATOR_ROLE(), managerAddress), "MODERATOR_ROLE not granted on dreRewardsDistributor to Manager");

        dreWithdrawalNFT standardNFT = dreWithdrawalNFT(standardNFTAddress);
        require(standardNFT.hasRole(standardNFT.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on STANDARD_NFT");
        require(standardNFT.hasRole(standardNFT.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on STANDARD_NFT");
        require(standardNFT.dreUSDManager() == managerAddress, "dreUSDManager not set on STANDARD_NFT to Manager");

        dreAaveAdapter adapter = dreAaveAdapter(payable(aaveAdapterAddress));
        require(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on dreAaveAdapter");
        require(adapter.hasRole(adapter.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on dreAaveAdapter");
        require(adapter.dreUSDManager() == managerAddress, "dreUSDManager not set on dreAaveAdapter to Manager");
        require(cfg.aaveV3Vault != address(0), "AAVE_V3_VAULT cannot be zero");
        require(adapter.vault() == cfg.aaveV3Vault, "dreAaveAdapter vault must match Config.aaveV3Vault");
        require(
            IERC20(adapter.aUsdc()).allowance(cfg.aaveV3Vault, aaveAdapterAddress) > 0,
            "aUSDC allowance from AAVE vault to dreAaveAdapter must be non-zero"
        );

        dreUSDManager manager = dreUSDManager(managerAddress);
        require(manager.hasRole(manager.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.MODERATOR_ROLE(), cfg.moderator), "MODERATOR_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.WITHDRAWAL_CONFIG_ROLE(), cfg.withdrawalConfig), "WITHDRAWAL_CONFIG_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.PAUSER_ROLE(), cfg.pauser), "PAUSER_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.KEEPER_ROLE(), cfg.managerKeeper), "KEEPER_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.EXPRESS_OPERATOR_ROLE(), cfg.managerExpressOperator), "EXPRESS_OPERATOR_ROLE not granted on dreUSDManager");
        require(manager.hasRole(manager.TREASURY_ROLE(), cfg.managerTreasury), "TREASURY_ROLE not granted on dreUSDManager");

        dreUSDOracle oracle = dreUSDOracle(oracleAddress);
        require(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), cfg.defaultAdmin), "DEFAULT_ADMIN_ROLE not granted on dreUSDOracle");
        require(oracle.hasRole(oracle.UPGRADER_ROLE(), cfg.upgrader), "UPGRADER_ROLE not granted on dreUSDOracle");
        require(oracle.hasRole(oracle.MODERATOR_ROLE(), cfg.moderator), "MODERATOR_ROLE not granted on dreUSDOracle");
    }
}

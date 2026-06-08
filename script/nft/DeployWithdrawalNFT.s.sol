// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { dreWithdrawalNFT } from "../../contracts/dreWithdrawalNFT.sol";
import { Config } from "../Config.sol";
import { SetupHelper } from "../utils/SetupHelper.s.sol";

/**
 * @title DeployWithdrawalNFT
 * @dev Deploys dreWithdrawalNFT (withdrawal queue positions) as UUPS proxy.
 *      After dreUSDManager is deployed, grant MINTER_ROLE and BURNER_ROLE to dreUSDManager.
 */
contract DeployWithdrawalNFT is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "DeployWithdrawalNFT only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address defaultAdmin = cfg.defaultAdmin;
        address upgrader = cfg.upgrader;
        address dreUSD = cfg.dreUSD;
        require(defaultAdmin != address(0), "DEFAULT_ADMIN cannot be zero address");
        require(upgrader != address(0), "UPGRADER cannot be zero address");
        require(dreUSD != address(0), "DREUSD_ADDRESS cannot be zero address");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be zero");
        uint256 adminPk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(adminPk != 0, "ADMIN_PRIVATE_KEY cannot be zero");

        vm.startBroadcast(pk);
        dreWithdrawalNFT standardNFT = _deployWithdrawalNFT("DRE Withdrawal", "dreWD", defaultAdmin, upgrader, dreUSD);
        dreWithdrawalNFT expressNFT = _deployWithdrawalNFT("DRE Express Withdrawal", "dreEXP", defaultAdmin, upgrader, dreUSD);
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        SetupHelper.setupWithdrawalNFTs(address(standardNFT), address(expressNFT), cfg.manager);
        vm.stopBroadcast();
    }

    function _deployWithdrawalNFT(string memory _name, string memory _symbol, address defaultAdmin, address upgrader, address dreUSD) internal returns (dreWithdrawalNFT nft) {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "WithdrawalNFT only on Base Sepolia or Base Mainnet");
        require(defaultAdmin != address(0), "defaultAdmin cannot be zero address");
        require(upgrader != address(0), "upgrader cannot be zero address");
        require(dreUSD != address(0), "dreUSD cannot be zero address");

        dreWithdrawalNFT implementation = new dreWithdrawalNFT();
        address proxyAddr = _deployProxy(implementation, _name, _symbol, defaultAdmin, upgrader, dreUSD);
        nft = dreWithdrawalNFT(proxyAddr);

        console.log("dreWithdrawalNFT implementation deployed at:", address(implementation));
        console.log("dreWithdrawalNFT proxy deployed at:", proxyAddr);
    }

    function _deployProxy(
        dreWithdrawalNFT implementation,
        string memory _name,
        string memory _symbol,
        address defaultAdmin,
        address upgrader,
        address dreUSD
    ) internal returns (address) {
        require(address(implementation) != address(0), "Implementation cannot be zero address");
        require(defaultAdmin != address(0), "defaultAdmin cannot be zero address");
        require(upgrader != address(0), "upgrader cannot be zero address");
        require(dreUSD != address(0), "dreUSD cannot be zero address");

        bytes memory initData = abi.encodeWithSelector(
            dreWithdrawalNFT.initialize.selector,
            dreUSD,
            _name,
            _symbol,
            defaultAdmin,
            upgrader
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        address deployedProxy = address(proxy);

        require(deployedProxy.code.length > 0, "Proxy deployment failed - no code at address");
        return deployedProxy;
    }
}

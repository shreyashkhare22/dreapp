// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Config } from "../Config.sol";
import { IdreRewardsDistributor } from "../../contracts/interfaces/IdreRewardsDistributor.sol";

/// @dev Grants MODERATOR_ROLE on dreRewardsDistributor (for addRewards). claimVested() is callable by anyone.
contract GrantModeratorRole is Script {
    function run() external {
        require(block.chainid == Config.BASE_SEPOLIA || block.chainid == Config.BASE_MAINNET, "GrantModeratorRole only on Base");
        Config.ChainConfig memory cfg = Config.getChainConfig(block.chainid);
        address moderatorAddress = vm.envOr("MODERATOR_ADDRESS", cfg.dreUSDs);
        address rewardsDistributor = cfg.rewardsDistributor;

        require(rewardsDistributor != address(0), "Rewards distributor cannot be zero address");
        require(moderatorAddress != address(0), "Moderator address cannot be zero address");

        uint256 pk = vm.envUint("ADMIN_PRIVATE_KEY");
        require(pk != 0, "ADMIN_PRIVATE_KEY is not set");
        vm.startBroadcast(pk);
        AccessControl(rewardsDistributor).grantRole(IdreRewardsDistributor(rewardsDistributor).MODERATOR_ROLE(), moderatorAddress);

        console.log("Moderator role granted to", moderatorAddress);
        vm.stopBroadcast();
    }
}

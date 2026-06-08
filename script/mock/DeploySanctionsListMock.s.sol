// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Config } from "../Config.sol";
import { SanctionsListMock } from "../../contracts/mocks/SanctionsListMock.sol";

/**
 * @title DeploySanctionsListMock
 * @notice Deploys {SanctionsListMock} for dev/test (e.g. as `SANCTIONS_LIST_ORACLE` for `DeploySanctionsListWhitelistWrapper`).
 * @dev Restricted to Base Sepolia, same as `DeployMock`.
 */
contract DeploySanctionsListMock is Script {
    function run() external virtual {
        require(block.chainid == Config.BASE_SEPOLIA, "DeploySanctionsListMock: only Base Sepolia");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(pk != 0, "PRIVATE_KEY cannot be empty");

        vm.startBroadcast(pk);
        SanctionsListMock mock = new SanctionsListMock();
        vm.stopBroadcast();

        console.log("SanctionsListMock deployed at:", address(mock));
    }
}

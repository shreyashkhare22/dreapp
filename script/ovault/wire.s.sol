// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppOptionsType3, EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {LZAddressContext} from "lz-address-book/helpers/LZAddressContext.sol";


/// @title OFTWireBase
/// @notice Base contract for wiring OFTs across multiple chains
/// @dev Contains reusable wiring logic (steps 2, 3, and 4):
///   - Step 2: Find current chain and setup context
///   - Step 3: Configuration functions (send/receive config, enforced options)
///   - Step 4: Configure pathways to all remote chains
abstract contract OFTWireBase is Script {
    using OptionsBuilder for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Configuration for a single chain
    /// @param chainId Native chain ID (e.g., 1 for Ethereum, 42161 for Arbitrum)
    /// @param oapp OApp address deployed on this chain
    /// @param confirmations Block confirmations required when this chain is source
    /// @param sendOptions Enforced options for MSG_TYPE_SEND (1) - gas for lzReceive
    /// @param sendAndCallOptions Enforced options for MSG_TYPE_SEND_AND_CALL (2) - empty if not using compose
    struct ChainConfig {
        uint256 chainId;
        address oapp;
        uint64 confirmations;
        bytes sendOptions;
        bytes sendAndCallOptions;
    }

    /// @dev Cached addresses for the local chain
    struct LocalContext {
        address oapp;
        address endpoint;
        address sendLib;
        address receiveLib;
        address executor;
        address[] dvns;
        uint64 confirmations;
        uint8 requiredDvnCount;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint32 internal constant MAX_MESSAGE_SIZE = 10000;

    uint16 internal constant MSG_TYPE_SEND = 1;
    uint16 internal constant MSG_TYPE_SEND_AND_CALL = 2;

    string internal constant DVN_1 = "LayerZero Labs";
    string internal constant DVN_2 = "Nethermind";
    string internal constant DVN_3 = "Canary";
    string internal constant DVN_4 = "Horizen";

    /*//////////////////////////////////////////////////////////////
                            PUBLIC WIRING FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Wire OFT across multiple chains
    /// @dev This function performs steps 2, 3, and 4 of the wiring process
    /// @param chains Array of chain configurations
    /// @param oappName Name of the OApp for logging purposes
    function wireOFT(ChainConfig[] memory chains, string memory oappName) public {
        // ============================================================
        // STEP 2: Find current chain and setup context
        // ============================================================
        (uint256 localIndex, LocalContext memory local, uint32[] memory eids) = _setup(chains);

        if (local.endpoint == address(0)) {
            console.log("Chain", block.chainid, "not in config. Skipping.");
            return;
        }

        console.log("=== Configuring chain", block.chainid, "===");
        console.log("OApp:", oappName);
        console.log("OApp address:", local.oapp);
        console.log("Endpoint:", local.endpoint);
        console.log("");

        // ============================================================
        // STEP 4: Configure pathways to all remote chains
        // ============================================================
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        for (uint256 i = 0; i < chains.length; i++) {
            if (i == localIndex) continue;
            _configurePathway(local, eids[i], chains[i]);
            console.log("Configured pathway to chain", chains[i].chainId);
            console.log("Configured pathway to EID", eids[i]);
        }

        vm.stopBroadcast();
        console.log("");
        console.log("=== Done ===");
    }

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function _setup(ChainConfig[] memory chains)
        internal
        returns (uint256 localIndex, LocalContext memory local, uint32[] memory eids)
    {
        // Find current chain by matching block.chainid
        localIndex = type(uint256).max;
        for (uint256 i = 0; i < chains.length; i++) {
            if (chains[i].chainId == block.chainid) {
                localIndex = i;
                break;
            }
        }

        if (localIndex == type(uint256).max) {
            return (0, local, eids);
        }

        // Setup address context
        LZAddressContext ctx = new LZAddressContext();
        ctx.setChainByChainId(block.chainid);

        uint32 localEid = ctx.getCurrentEID();
        bool isTestnet = _lzEidIsTestnet(localEid);

        local = LocalContext({
            oapp: chains[localIndex].oapp,
            endpoint: ctx.getEndpointV2(),
            sendLib: ctx.getSendUln302(),
            receiveLib: ctx.getReceiveUln302(),
            executor: ctx.getExecutor(),
            dvns: ctx.getSortedDVNs(_getDvnNames(isTestnet)),
            confirmations: chains[localIndex].confirmations,
            requiredDvnCount: isTestnet ? uint8(2) : uint8(4)
        });

        // Resolve all EIDs
        eids = new uint32[](chains.length);
        for (uint256 i = 0; i < chains.length; i++) {
            ctx.setChainByChainId(chains[i].chainId);
            eids[i] = ctx.getCurrentEID();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Configure a single pathway to a remote chain (Step 3)
    /// @dev This performs:
    ///   1. Set libraries for this pathway
    ///   2. Set send config (local -> remote)
    ///   3. Set receive config (remote -> local)
    ///   4. Set enforced options
    ///   5. Set peer connection
    function _configurePathway(LocalContext memory local, uint32 remoteEid, ChainConfig memory remote) internal {
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(local.endpoint);

        // 1. Set libraries for this pathway (skip if already set to avoid LZ_SameValue)
        if (endpoint.getSendLibrary(local.oapp, remoteEid) != local.sendLib) {
            endpoint.setSendLibrary(local.oapp, remoteEid, local.sendLib);
        }
        (address currentReceiveLib,) = endpoint.getReceiveLibrary(local.oapp, remoteEid);
        if (currentReceiveLib != local.receiveLib) {
            endpoint.setReceiveLibrary(local.oapp, remoteEid, local.receiveLib, 0);
        }

        // 2. Set send config (local -> remote): use local's confirmations (local is the source)
        _setSendConfig(local, remoteEid, local.confirmations);

        // 3. Set receive config (remote -> local): use remote's confirmations (remote is the source)
        _setReceiveConfig(local, remoteEid, remote.confirmations);

        // 4. Set enforced options (gas to deliver to remote chain)
        _setEnforcedOptions(local.oapp, remoteEid, remote.sendOptions, remote.sendAndCallOptions);

        // 5. Set peer to open the pathway
        IOAppCore(local.oapp).setPeer(remoteEid, bytes32(uint256(uint160(remote.oapp))));
    }

    function _setSendConfig(LocalContext memory local, uint32 remoteEid, uint64 confirmations) internal {
        SetConfigParam[] memory params = new SetConfigParam[](2);

        params[0] = SetConfigParam({
            eid: remoteEid,
            configType: 1,
            config: abi.encode(ExecutorConfig({maxMessageSize: MAX_MESSAGE_SIZE, executor: local.executor}))
        });

        params[1] = SetConfigParam({
            eid: remoteEid,
            configType: 2,
            config: abi.encode(
                UlnConfig({
                    confirmations: confirmations,
                    requiredDVNCount: local.requiredDvnCount,
                    optionalDVNCount: 0,
                    optionalDVNThreshold: 0,
                    requiredDVNs: local.dvns,
                    optionalDVNs: new address[](0)
                })
            )
        });

        ILayerZeroEndpointV2(local.endpoint).setConfig(local.oapp, local.sendLib, params);
    }

    function _setReceiveConfig(LocalContext memory local, uint32 remoteEid, uint64 confirmations) internal {
        SetConfigParam[] memory params = new SetConfigParam[](1);

        params[0] = SetConfigParam({
            eid: remoteEid,
            configType: 2,
            config: abi.encode(
                UlnConfig({
                    confirmations: confirmations,
                    requiredDVNCount: local.requiredDvnCount,
                    optionalDVNCount: 0,
                    optionalDVNThreshold: 0,
                    requiredDVNs: local.dvns,
                    optionalDVNs: new address[](0)
                })
            )
        });

        ILayerZeroEndpointV2(local.endpoint).setConfig(local.oapp, local.receiveLib, params);
    }

    function _setEnforcedOptions(
        address oapp,
        uint32 remoteEid,
        bytes memory sendOptions,
        bytes memory sendAndCallOptions
    ) internal {
        uint256 count = 1;
        if (sendAndCallOptions.length > 0) count = 2;

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](count);

        // MSG_TYPE_SEND (1) - standard transfer
        enforcedOptions[0] = EnforcedOptionParam({eid: remoteEid, msgType: MSG_TYPE_SEND, options: sendOptions});

        // MSG_TYPE_SEND_AND_CALL (2) - transfer with compose
        if (sendAndCallOptions.length > 0) {
            enforcedOptions[1] =
                EnforcedOptionParam({eid: remoteEid, msgType: MSG_TYPE_SEND_AND_CALL, options: sendAndCallOptions});
        }

        IOAppOptionsType3(oapp).setEnforcedOptions(enforcedOptions);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev LayerZero testnet EIDs in this address book use the 40xxx range; mainnets use 30xxx / 31xxx / etc.
    function _lzEidIsTestnet(uint32 eid) internal pure returns (bool) {
        return eid >= 40_000 && eid < 50_000;
    }

    function _getDvnNames(bool isTestnet) internal pure returns (string[] memory names) {
        if (isTestnet) {
            names = new string[](2);
            names[0] = DVN_1;
            names[1] = DVN_2;
        } else {
            names = new string[](4);
            names[0] = DVN_1;
            names[1] = DVN_2;
            names[2] = DVN_3;
            names[3] = DVN_4;
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

library Config {
    // ======== Chain IDs ========
    uint256 constant ETH_MAINNET = 1;
    uint256 constant ETH_SEPOLIA = 11155111;
    uint256 constant BASE_SEPOLIA = 84532;
    uint256 constant BASE_MAINNET = 8453;
    uint256 constant POLYGON_MAINNET = 137;
    uint256 constant ARBITRUM_ONE = 42161;
    uint256 constant MONAD_MAINNET = 143;
    uint256 constant MEGAETH_MAINNET = 4326;
    uint256 constant INK_MAINNET = 57073;

    // ======== Shared (only CREATE2 and LZ endpoints) ========
    address constant DEFAULT_CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address constant LZ_ENDPOINT_V2_TESTNET = 0x6EDCE65403992e310A62460808c4b910D972f10f; // Ethereum Sepolia, Base Sepolia
    address constant LZ_ENDPOINT_V2_MAINNET = 0x1a44076050125825900e736c501f859c50fE728c; // Base, Ethreum Mainnet
    address constant LZ_ENDPOINT_V2_MONAD_MAINNET = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B; // Monad Mainnet
    address constant LZ_ENDPOINT_V2_MEGAETH_MAINNET = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B; // MegaETH Mainnet
    address constant LZ_ENDPOINT_V2_INK_MAINNET = 0xca29f3A6f966Cb2fc0dE625F8f325c0C46dbE958; // Ink Mainnet

    /// @dev Addresses that receive DEFAULT_ADMIN_ROLE, UPGRADER_ROLE, and GUARDIAN_ROLE on dreUSD for that spoke (`DeployDreSystem._deploySpokeChain`). Often the CREATE2 deploy delegate; set before mainnet spoke deploy.
    address constant MAINNET_SPOKE_ETHEREUM_ADMIN = address(0); // todo set these before deployment on mainnet spokes
    address constant MAINNET_SPOKE_POLYGON_ADMIN = address(0);
    address constant MAINNET_SPOKE_ARBITRUM_ADMIN = address(0);
    address constant MAINNET_SPOKE_MONAD_ADMIN = address(0);
    address constant MAINNET_SPOKE_MEGAETH_ADMIN = address(0);
    address constant MAINNET_SPOKE_INK_ADMIN = address(0);

    address constant MAINNET_DREUSD = 0xB4E008A61b5A7A7D0e1aebd639F704d24821Bb2F;
    address constant MAINNET_DRE_SHARE_OFT = address(0); // todo set this after deployment on mainnet spokes

    /// @notice Chain-specific config (roles, protocol contracts, oracles, assets).
    struct ChainConfig {
        address defaultAdmin;
        address upgrader;
        address guardian;
        address moderator;
        address withdrawalConfig;
        address pauser;
        address custodian;
        address custodianVault;
        address stuckFundsRecipient;
        uint256 dailyFiatMintCapUsd;
        address expressPaybackAddress;
        address expressFeeRecipient;
        address sanctionsList;
        uint256 rewardsDistributorApprovalAmount;
        address managerTreasury;
        address managerExpressOperator;
        address managerKeeper;
        address aaveV3Pool;
        address aaveV3Vault;
        address usdc;
        address usdt;
        address usdcOracleFeed;
        address usdtOracleFeed;
        uint256 stalenessThresholdSeconds;
        address dreUSD;
        address dreUSDs;
        address rewardsDistributor;
        address oracle;
        address withdrawalNFT;
        address expressWithdrawalNFT;
        address manager;
        address aaveV3Adapter;
        address dreShareOFTAdapter;
        address dreShareOFT;
        address dreOVaultComposer;
        /// @notice dreVault hop 2 `forwardVault` (corporate / Utila wallet). Set before mainnet deploy.
        address vault2ForwardVault;
    }

    /**
     * @notice Returns chain-specific config. Reverts for unsupported chainId.
     * @dev For ETH_SEPOLIA set roles and dreShareOFT (spoke); endpoint is getLzEndpoint(ETH_SEPOLIA).
     * @dev Mainnet spokes: set `MAINNET_SPOKE_*_ADMIN`, `MAINNET_DREUSD`, and `MAINNET_DRE_SHARE_OFT` (shared across all mainnet spokes).
     */
    function getChainConfig(uint256 chainId) internal pure returns (ChainConfig memory c) {
        if (chainId == ETH_SEPOLIA) return _ethSepoliaConfig();
        if (chainId == BASE_SEPOLIA) return _baseSepoliaConfig();
        if (chainId == BASE_MAINNET) return _baseMainnetConfig();
        if (chainId == ETH_MAINNET) return _ethereumMainnetSpokeConfig();
        if (chainId == POLYGON_MAINNET) return _polygonMainnetSpokeConfig();
        if (chainId == ARBITRUM_ONE) return _arbitrumOneMainnetSpokeConfig();
        if (chainId == MONAD_MAINNET) return _monadMainnetSpokeConfig();
        if (chainId == MEGAETH_MAINNET) return _megaethMainnetSpokeConfig();
        if (chainId == INK_MAINNET) return _inkMainnetSpokeConfig();
        revert("Config: unsupported chain");
    }

    function _ethSepoliaConfig() internal pure returns (ChainConfig memory c) {
        c.defaultAdmin = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05; // set to delegate used for ShareOFT CREATE2
        c.upgrader = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.guardian = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.dreUSD = 0xf84d02939c6d187b94e233AaB10212b0b8a2eede;
        c.dreShareOFT = 0x82a7A0a5d7D815C663894dFD172dDB9e7Ee72809;
    }

    function _baseSepoliaConfig() internal pure returns (ChainConfig memory c) {
        c.defaultAdmin = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.upgrader = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.guardian = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.moderator = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.withdrawalConfig = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.pauser = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.custodian = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.custodianVault = 0x192F945CAA2c394af5AB1F578D8283E193854E43;
        c.stuckFundsRecipient = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.dailyFiatMintCapUsd = 10_000_000e2;
        c.expressPaybackAddress = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.expressFeeRecipient = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.sanctionsList = 0x913fe5EE42200D6Ee2EFbB4CF7F6372CF9cC71C3; // SanctionsListMock
        c.rewardsDistributorApprovalAmount = type(uint256).max;
        c.managerTreasury = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.managerExpressOperator = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.managerKeeper = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.aaveV3Pool = 0x249c4eB1FA3632DEDccC7317855f2056910E62C7; // from aave documentation
        c.aaveV3Vault = 0x0C78AF0fb1F4E09dF9421ba9abD75C4dc018DB05;
        c.usdc = 0x4BFf12Dec183b102E74275df6Bd07598b5650496;
        c.usdt = 0x323e78f944A9a1FcF3a10efcC5319DBb0bB6e673;
        c.usdcOracleFeed = 0x342F4DbbaFFdD89F332Bb02422ec187C0e49a49f; // from chainlink documentation
        c.usdtOracleFeed = 0x342F4DbbaFFdD89F332Bb02422ec187C0e49a49f; // from chainlink documentation
        c.stalenessThresholdSeconds = 3600 * 24 * 1;
        // dre addresses
        c.dreUSD = 0xf84d02939c6d187b94e233AaB10212b0b8a2eede;
        c.dreUSDs = 0x8D5e2A71ACb8D2408de0784FBd6465fc23fcAE4b;
        c.rewardsDistributor = 0xA9617B98805F8D7A17b80d857dfBfEeD6c144163;
        c.oracle = 0x31c276306087f9CB2e5915dB412DA035881d15D3;
        c.withdrawalNFT = 0xA249A6d53b135588b814B82e0b317067D14a4baf;
        c.expressWithdrawalNFT = 0xEf5Fa722F1B233F2Ed7dA1a5C6326cE859E6C0Ab;
        c.manager = 0x1148564b1F0a724467CCfc7def8becbE1fff5A56;
        c.aaveV3Adapter = 0xa30e833af2C8E801078e759c4B52e302d34c8d50;
        c.dreShareOFTAdapter = 0x7735452fa7B8711B9C90BA9e392babd381789d2C;
        c.dreOVaultComposer = 0xce79BE541Db2bB43b32B643AAA1A8c6C8e506FfF;
        c.dreShareOFT = 0x82a7A0a5d7D815C663894dFD172dDB9e7Ee72809;
        c.vault2ForwardVault = 0x0721aF1BcedB40E2048d35dfC6245e4A00128D8D;
    }

    function _baseMainnetConfig() internal pure returns (ChainConfig memory c) {
        c.defaultAdmin = 0x23F9D2395B8fB217a4Ea6C66c2800061D976A8ea;
        c.upgrader = 0x2dd0dA95738F2cCBa599418Ae90930Fe7FaeAE91;
        c.guardian = 0x35d40B8E66cc318bB0Bfb35F6e6D872B9CA314BB;
        c.moderator = 0xf65972817BBf1cf7de10DA69C9F46E793D9aF981;
        c.withdrawalConfig = 0xf65972817BBf1cf7de10DA69C9F46E793D9aF981; //moderator
        c.pauser = 0x3F6Bb9C84BaB9c0ceE86F340346fD2fEEE6Bc608;
        c.custodian = address(0); // custodian address for fiat mint signature verification
        c.custodianVault = 0xF25AA5ECF4334B12DCB8944Ca3E5a6dbF5F8a349; // address that receives stablecoins when minting
        c.stuckFundsRecipient = 0x73b957d1C06DA12B196b62082Cb59b426657c3f8; // address that receives funds when cross chain transfer fails - treasury
        c.dailyFiatMintCapUsd = 10_000_000e2;
        c.expressPaybackAddress = 0x73b957d1C06DA12B196b62082Cb59b426657c3f8; // address where express filler receives payback - treasury
        c.expressFeeRecipient = 0x73b957d1C06DA12B196b62082Cb59b426657c3f8; // address that receives express withdrawal fees - treasury
        c.sanctionsList = 0x3A91A31cB3dC49b4db9Ce721F50a9D076c8D739B;
        c.rewardsDistributorApprovalAmount = type(uint256).max;
        c.managerTreasury = 0x73b957d1C06DA12B196b62082Cb59b426657c3f8; // TREASURY_ROLE on manager
        c.managerExpressOperator = 0x73b957d1C06DA12B196b62082Cb59b426657c3f8; // EXPRESS_OPERATOR_ROLE on manager - treasury
        c.managerKeeper = 0xf65972817BBf1cf7de10DA69C9F46E793D9aF981; // KEEPER_ROLE on manager - moderator
        c.aaveV3Pool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // Base Aave V3 Pool
        // todo: allow  dreAaveAdapter to transfer aUSDC from this address
        c.aaveV3Vault = 0x73b957d1C06DA12B196b62082Cb59b426657c3f8;   // address that has aUSDC and allows transfers to dreAaveAdapter - treasury
        c.usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
        c.usdt = address(0); // Base USDT
        c.usdcOracleFeed = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B; // https://data.chain.link/feeds/base/base/usdc-usd
        c.usdtOracleFeed = address(0); // https://data.chain.link/feeds/base/base/usdt-usd
        c.stalenessThresholdSeconds = 3600 * 24 * 1;

        // deployed contracts
        c.dreUSD = MAINNET_DREUSD;
        c.dreUSDs = 0x13F7Cbd3562e276b49AAdFf9b3Eef67561371bcF;
        c.rewardsDistributor = 0x0C5990D188734a3918d793751FB9D9426d5487B2;
        c.oracle = 0x9Db85D8201d14ad7602aaFaC249F37Aa0B6D99b5;
        c.withdrawalNFT = 0x3a5801950282645811f379E272F68b31A80bBC09;
        c.expressWithdrawalNFT = 0x5C156B79C9c9f906d9d8Eea59bB0D2779abBf494;
        c.manager = 0xa02557918d04973A712d7dFe2A5C735fC0117Ac8;
        c.aaveV3Adapter = 0xb10d4843f1F7A807Be8362d009C5eeA78ef4253f;
        c.dreShareOFTAdapter = 0xE4F808b1eBff059052529E66EA13c4b171DdDe3b;
        c.dreShareOFT = MAINNET_DRE_SHARE_OFT;
        c.dreOVaultComposer = 0xFFCCD2d1616D28eEd874D1c68c183f704f6da7bC;
        c.vault2ForwardVault = address(0); // todo set Utila corporate wallet before mainnet dreVault deploy
    }

     /// @notice LayerZero ULN block confirmations when `chainId` is the message source chain
    function confirmationsForChain(uint256 chainId) internal pure returns (uint64) {
        if (chainId == BASE_SEPOLIA || chainId == BASE_MAINNET) return 3;
        if (chainId == ARBITRUM_ONE || chainId == INK_MAINNET || chainId == MEGAETH_MAINNET) return 3;
        if (chainId == ETH_SEPOLIA) return 10;
        if (chainId == ETH_MAINNET) return 32;
        if (chainId == POLYGON_MAINNET) return 128;
        if (chainId == MONAD_MAINNET) return 10;
        return 10;
    }

    /// @dev Base hub + dreUSD OFT peers on mainnet (wireDreUSD full mesh)
    function dreUsdMainnetChainIds() internal pure returns (uint256[] memory ids) {
        ids = new uint256[](7);
        ids[0] = BASE_MAINNET;
        ids[1] = ETH_MAINNET;
        ids[2] = POLYGON_MAINNET;
        ids[3] = MONAD_MAINNET;
        ids[4] = MEGAETH_MAINNET;
        ids[5] = INK_MAINNET;
        ids[6] = ARBITRUM_ONE;
    }

    function isDreUsdMainnetChain(uint256 chainId) internal pure returns (bool) {
        return chainId == BASE_MAINNET || chainId == ETH_MAINNET || chainId == POLYGON_MAINNET
            || chainId == MONAD_MAINNET || chainId == MEGAETH_MAINNET || chainId == INK_MAINNET
            || chainId == ARBITRUM_ONE;
    }

    /// @dev Spokes that host dreShareOFT opposite Base mainnet hub (wireShareOFT hub → spoke list)
    function shareOftMainnetSpokeChainIds() internal pure returns (uint256[] memory ids) {
        ids = new uint256[](6);
        ids[0] = ETH_MAINNET;
        ids[1] = POLYGON_MAINNET;
        ids[2] = MONAD_MAINNET;
        ids[3] = MEGAETH_MAINNET;
        ids[4] = INK_MAINNET;
        ids[5] = ARBITRUM_ONE;
    }

    function _isMainnetMinimalSpoke(uint256 chainId) internal pure returns (bool) {
        return chainId == ETH_MAINNET || chainId == POLYGON_MAINNET || chainId == ARBITRUM_ONE
            || chainId == MONAD_MAINNET || chainId == MEGAETH_MAINNET || chainId == INK_MAINNET;
    }

    function _mainnetSpokeRolesShell(address admin) internal pure returns (ChainConfig memory c) {
        c.defaultAdmin = admin;
        c.upgrader = admin;
        c.guardian = admin;
        c.dreUSD = MAINNET_DREUSD;
        c.dreShareOFT = MAINNET_DRE_SHARE_OFT;
    }

    function _ethereumMainnetSpokeConfig() internal pure returns (ChainConfig memory c) {
        c = _mainnetSpokeRolesShell(MAINNET_SPOKE_ETHEREUM_ADMIN);
    }

    function _polygonMainnetSpokeConfig() internal pure returns (ChainConfig memory c) {
        c = _mainnetSpokeRolesShell(MAINNET_SPOKE_POLYGON_ADMIN);
    }

    function _arbitrumOneMainnetSpokeConfig() internal pure returns (ChainConfig memory c) {
        c = _mainnetSpokeRolesShell(MAINNET_SPOKE_ARBITRUM_ADMIN);
    }

    function _monadMainnetSpokeConfig() internal pure returns (ChainConfig memory c) {
        c = _mainnetSpokeRolesShell(MAINNET_SPOKE_MONAD_ADMIN);
    }

    function _megaethMainnetSpokeConfig() internal pure returns (ChainConfig memory c) {
        c = _mainnetSpokeRolesShell(MAINNET_SPOKE_MEGAETH_ADMIN);
    }

    function _inkMainnetSpokeConfig() internal pure returns (ChainConfig memory c) {
        c = _mainnetSpokeRolesShell(MAINNET_SPOKE_INK_ADMIN);
    }

    /**
     * @notice Returns the LayerZero endpoint address for a given chain ID
     */
    function getLzEndpoint(uint256 chainId) internal pure returns (address endpoint) {
        if (chainId == ETH_SEPOLIA) return LZ_ENDPOINT_V2_TESTNET; // Ethereum Sepolia
        if (chainId == BASE_SEPOLIA) return LZ_ENDPOINT_V2_TESTNET;
        if (chainId == BASE_MAINNET) return LZ_ENDPOINT_V2_MAINNET;
        if (chainId == MONAD_MAINNET) return LZ_ENDPOINT_V2_MONAD_MAINNET;
        if (chainId == MEGAETH_MAINNET) return LZ_ENDPOINT_V2_MEGAETH_MAINNET;
        if (chainId == INK_MAINNET) return LZ_ENDPOINT_V2_INK_MAINNET;
        if (_isMainnetMinimalSpoke(chainId)) return LZ_ENDPOINT_V2_MAINNET;
        return address(0);
    }
}

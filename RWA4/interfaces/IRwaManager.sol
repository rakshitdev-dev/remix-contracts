// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ILegalRegistry} from "./ILegalRegistry.sol";
import {IIdentityRegistry} from "./IIdentityRegistry.sol";

interface IRwaManager {
    /* ============================== STRUCTS ============================== */

    struct RwaInfo {
        uint256 assetId;
        address token;
        string name;
        string symbol;
        uint256 cap;
        uint256 price;
        address propertyManager;
        uint256 totalSupply;
        ILegalRegistry.AssetStatus status;
        string documentURI;
        string[] countryCodes;
        address legalPropertyOwner;
    }

    /* ============================== EVENTS ============================== */

    event RWACreated(uint256 indexed assetId, address indexed token);

    event RwaImplementationUpdated(
        address indexed oldImpl,
        address indexed newImpl
    );

    /* ============================== ERRORS ============================== */

    error ZeroAddress();
    error AssetNotApproved();
    error AlreadyTokenized();
    error InvalidDistribution();
    error IdentityMissing(address user);
    error CountryMismatch(
        address user,
        string identityCountry,
        string assetCountry
    );

    /* ============================== OWNERSHIP ============================== */

    /**
     * @notice Returns the owner (admin) of the RWA Manager
     * @dev Compatible with OpenZeppelin Ownable / OwnableUpgradeable
     */
    function owner() external view returns (address);

    /* ============================== ADMIN ============================== */

    function updateRwaImplementation(address newImpl) external;

    /* ============================== CORE ============================== */

    function createRwa(
        string calldata name,
        string calldata symbol,
        uint256 assetId,
        uint256 cap,
        uint256 price
    ) external returns (address token);

    /* ============================== VIEWS ============================== */

    function rwaImplementation() external view returns (address);

    function legalRegistry() external view returns (ILegalRegistry);

    function identityRegistry() external view returns (IIdentityRegistry);

    function rwaByAsset(uint256 assetId) external view returns (address);

    function totalRWAs() external view returns (uint256);

    function getAllRWATokens() external view returns (address[] memory);

    function getRWATokens(
        uint256 page,
        uint256 limit
    ) external view returns (address[] memory);

    function getAllRWAsWithData() external view returns (RwaInfo[] memory);

    function getRWAsWithData(
        uint256 page,
        uint256 limit
    ) external view returns (RwaInfo[] memory);
}

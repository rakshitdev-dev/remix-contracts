// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IIdentityRegistry} from "./IIdentityRegistry.sol";

/**
 * @title ILegalRegistry
 * @author Rakshit Kumar Singh
 * @notice Interface for LegalRegistry contract
 *
 * @dev
 *  - Manages RWA jurisdiction validation
 *  - Handles asset approval lifecycle
 *  - Integrates with IdentityRegistry
 */
interface ILegalRegistry {
    /*===============================ENUMS===============================*/

    enum AssetStatus {
        NONE,
        REQUESTED,
        APPROVED,
        DISAPPROVED
    }

    /*===============================STRUCTS===============================*/

    struct Asset {
        address propertyOwner;
        string[] countryCodes;
        string documentURI;
        AssetStatus status;
    }

    /*===============================EVENTS===============================*/

    event AssetRequested(uint256 indexed assetId, address indexed owner);
    event AssetReRequested(uint256 indexed assetId);
    event AssetApproved(uint256 indexed assetId);
    event AssetDisapproved(uint256 indexed assetId, string reason);

    /*===============================ERRORS===============================*/

    error InvalidStatus();
    error NotOwner();
    error IdentityNotVerified();
    error JurisdictionMismatch();

    /*===============================VIEWS===============================*/

    function totalAssets() external view returns (uint256);

    function identityRegistry()
        external
        view
        returns (IIdentityRegistry);

    function isAssetApproved(uint256 assetId)
        external
        view
        returns (bool);

    function getAsset(
        uint256 assetId
    )
        external
        view
        returns (
            address propertyOwner,
            string[] memory countryCodes,
            string memory documentURI,
            AssetStatus status
        );

    function validateJurisdiction(
        address user,
        uint256 assetId
    ) external view;

    /*===============================USER FUNCTIONS===============================*/

    function requestAsset(
        string[] calldata countryCodes,
        string calldata documentURI
    ) external returns (uint256 assetId);

    function reRequestAsset(
        uint256 assetId,
        string[] calldata countryCodes,
        string calldata documentURI
    ) external;

    /*===============================ADMIN FUNCTIONS===============================*/

    function approve(uint256 assetId) external;

    function disapprove(
        uint256 assetId,
        string calldata reason
    ) external;
}
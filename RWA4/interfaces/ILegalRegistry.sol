// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title ILegalRegistry
 * @author Rakshit Kumar Singh
 * @dev Interface MUST exactly match LegalRegistry ABI.
 *
 *      - Used by RwaManager and other system contracts
 *      - Provides read access to asset legal state
 *      - Exposes jurisdiction validation
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

    /*===============================USER FUNCTIONS===============================*/

    /**
     * @notice Requests approval for a new asset.
     */
    function requestAsset(
        string[] calldata countryCodes,
        string calldata documentURI
    ) external returns (uint256 assetId);

    /**
     * @notice Re-requests approval for a previously disapproved asset.
     */
    function reRequestAsset(
        uint256 assetId,
        string[] calldata countryCodes,
        string calldata documentURI
    ) external;

    /*===============================COMPLIANCE===============================*/

    /**
     * @notice Validates whether a user is legally allowed
     *         to interact with the given asset.
     *
     * @dev Reverts if jurisdiction or identity is invalid.
     */
    function validateJurisdiction(address user, uint256 assetId) external view;

    /*===============================VIEWS===============================*/

    function isAssetApproved(uint256 assetId) external view returns (bool);

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
}

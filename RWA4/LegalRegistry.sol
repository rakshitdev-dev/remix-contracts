// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";

/**
 * @title LegalRegistry
 * @author Rakshit Kumar Singh
 * @dev Maintains legal jurisdiction and approval status for RWAs.
 *
 *      - Enforces jurisdiction alignment with verified user identity
 *      - Assets must be approved before tokenization
 */
contract LegalRegistry is Ownable {
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

    /*===============================STORAGE===============================*/

    mapping(uint256 => Asset) private assets;
    uint256 private _nextAssetId = 1;
    uint256 public totalAssets;

    IIdentityRegistry public immutable identityRegistry;

    /*===============================EVENTS===============================*/

    event AssetRequested(uint256 indexed assetId, address indexed owner);
    event AssetReRequested(uint256 indexed assetId);
    event AssetApproved(uint256 indexed assetId);
    event AssetDisapproved(uint256 indexed assetId, string reason);

    /*===============================ERRORS===============================*/

    error InvalidId();
    error InvalidStatus();
    error NotOwner();
    error IdentityNotVerified();
    error JurisdictionMismatch();

    /*===============================CONSTRUCTOR===============================*/

    constructor(
        address initialOwner,
        address identityRegistryAddress
    ) Ownable(initialOwner) {
        identityRegistry = IIdentityRegistry(identityRegistryAddress);
    }

    /*===============================INTERNAL===============================*/

    /**
     * @dev Validates that the user has a valid identity and
     *      that the user's country matches at least one
     *      allowed asset jurisdiction.
     */
    function validateJurisdiction(address user, uint256 assetId) public view {
        if (!identityRegistry.hasValidIdentity(user)) {
            revert IdentityNotVerified();
        }

        Asset storage ass = assets[assetId];
        IIdentityRegistry.Identity memory id = identityRegistry.getIdentity(
            user
        );

        bool allowed = false;

        for (uint256 i = 0; i < ass.countryCodes.length; i++) {
            if (
                keccak256(bytes(id.countryCode)) ==
                keccak256(bytes(ass.countryCodes[i]))
            ) {
                allowed = true;
                break;
            }
        }

        if (!allowed) {
            revert JurisdictionMismatch();
        }
    }

    /*===============================USER FUNCTIONS===============================*/

    /**
     * @notice Requests approval for a new asset.
     */
    function requestAsset(
        string[] calldata countryCodes,
        string calldata documentURI
    ) external returns (uint256 assetId) {
        IIdentityRegistry.Identity memory iden = identityRegistry.getIdentity(
            msg.sender
        );

        require(
            iden.typ == IIdentityRegistry.IDENTITYTYPE.owner,
            "Only property owner identity allowed"
        );
        assetId = _nextAssetId++;

        Asset storage a = assets[assetId];
        a.propertyOwner = msg.sender;
        a.documentURI = documentURI;
        a.status = AssetStatus.REQUESTED;

        for (uint256 i = 0; i < countryCodes.length; i++) {
            a.countryCodes.push(countryCodes[i]);
        }

        validateJurisdiction(msg.sender, assetId);

        totalAssets++;
        emit AssetRequested(assetId, msg.sender);
    }

    /**
     * @notice Re-requests approval for a previously disapproved asset.
     */
    function reRequestAsset(
        uint256 assetId,
        string[] calldata countryCodes,
        string calldata documentURI
    ) external {
        if (assetId < 1) revert InvalidId();
        IIdentityRegistry.Identity memory iden = identityRegistry.getIdentity(
            msg.sender
        );

        require(
            iden.typ == IIdentityRegistry.IDENTITYTYPE.owner,
            "Only property owner identity allowed"
        );
        Asset storage a = assets[assetId];

        if (a.status != AssetStatus.DISAPPROVED) revert InvalidStatus();
        if (a.propertyOwner != msg.sender) revert NotOwner();

        delete a.countryCodes;

        for (uint256 i = 0; i < countryCodes.length; i++) {
            a.countryCodes.push(countryCodes[i]);
        }

        a.documentURI = documentURI;
        a.status = AssetStatus.REQUESTED;

        validateJurisdiction(msg.sender, assetId);

        emit AssetReRequested(assetId);
    }

    /*===============================ADMIN FUNCTIONS===============================*/

    function approveAsset(uint256 assetId) external onlyOwner {
        if (assetId < 1) revert InvalidId();
        if (assets[assetId].status != AssetStatus.REQUESTED && assets[assetId].status != AssetStatus.DISAPPROVED)
            revert InvalidStatus();

        assets[assetId].status = AssetStatus.APPROVED;
        emit AssetApproved(assetId);
    }

    function disapproveAsset(
        uint256 assetId,
        string calldata reason
    ) external onlyOwner {
        if (assets[assetId].status != AssetStatus.REQUESTED && assets[assetId].status != AssetStatus.APPROVED)
            revert InvalidStatus();

        assets[assetId].status = AssetStatus.DISAPPROVED;
        emit AssetDisapproved(assetId, reason);
    }

    /*===============================VIEWS===============================*/

    function isAssetApproved(uint256 assetId) external view returns (bool) {
        if (assetId < 1) revert InvalidId();
        return assets[assetId].status == AssetStatus.APPROVED;
    }

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
        )
    {
        if (assetId < 1) revert InvalidId();
        Asset storage a = assets[assetId];
        return (a.propertyOwner, a.countryCodes, a.documentURI, a.status);
    }
}

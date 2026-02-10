// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IdentityRegistry
 * @author Rakshit Kumar Singh
 * @dev Manages on-chain identity verification for users.
 *
 *      - Only the contract owner can register, update, or revoke identities.
 *      - Used by RWA tokens and manager contracts to enforce identity checks.
 */
contract IdentityRegistry is Ownable {
    /*===============================ENUMS===============================*/

    enum KYCLEVEL {
        none,
        basic,
        enhanced
    }

    /**
     * @dev Risk classification assigned off-chain by the administrator.
     *      This enum is informational and not enforced by on-chain logic.
     */
    enum RISKSCOREBAND {
        low,
        medium,
        high
    }

    /**
     * @dev Investor classification assigned off-chain by the administrator.
     *      This enum is informational and not enforced by on-chain logic.
     */
    enum INVESTORCLASS {
        retail,
        professional,
        accredited
    }

    /*===============================STRUCTS===============================*/

    /**
     * @dev Represents a verified on-chain identity.
     */
    struct Identity {
        uint256 verifiedTill;      // Expiry timestamp
        string identityURI;        // Off-chain KYC reference
        string countryCode;        // ISO / jurisdiction code (e.g., IN, US, +91)
        KYCLEVEL level;            // KYC level
        RISKSCOREBAND risk;        // Risk band
        INVESTORCLASS class;       // Investor class
    }

    /*===============================STORAGE===============================*/

    mapping(address => Identity) private _identities;

    /*===============================EVENTS===============================*/

    event IdentityRegistered(
        address indexed user,
        uint256 verifiedTill,
        string countryCode,
        string identityURI,
        KYCLEVEL level,
        RISKSCOREBAND risk,
        INVESTORCLASS class
    );

    event IdentityUpdated(address indexed user);
    event IdentityRevoked(address indexed user);

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error IdentityAlreadyVerified();
    error IdentityDoesNotExist();
    error IdentityInvalid(address user);

    /*===============================CONSTRUCTOR===============================*/

    constructor(address initialOwner) Ownable(initialOwner) {}

    /*===============================VIEWS===============================*/

    /**
     * @notice Returns true if the identity exists and is not expired.
     */
    function hasValidIdentity(address user) public view returns (bool) {
        Identity storage identity = _identities[user];
        return identity.verifiedTill != 0 && identity.verifiedTill >= block.timestamp;
    }

    /**
     * @dev Modifier to restrict access to verified identities.
     */
    modifier onlyVerified() {
        if (!hasValidIdentity(msg.sender)) {
            revert IdentityInvalid(msg.sender);
        }
        _;
    }

    /*===============================ADMIN FUNCTIONS===============================*/

    /**
     * @notice Registers a new identity.
     * @dev Only callable by the contract owner.
     */
    function registerIdentity(
        address user,
        uint256 verifiedTill,
        string calldata identityURI,
        string calldata countryCode,
        KYCLEVEL level,
        RISKSCOREBAND risk,
        INVESTORCLASS class
    ) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (_identities[user].verifiedTill != 0)
            revert IdentityAlreadyVerified();

        _identities[user] = Identity({
            verifiedTill: verifiedTill,
            identityURI: identityURI,
            countryCode: countryCode,
            level: level,
            risk: risk,
            class: class
        });

        emit IdentityRegistered(
            user,
            verifiedTill,
            countryCode,
            identityURI,
            level,
            risk,
            class
        );
    }

    /**
     * @notice Updates an existing identity.
     * @dev Only callable by the contract owner.
     */
    function updateIdentity(
        address user,
        uint256 newVerifiedTill,
        string calldata newIdentityURI,
        string calldata newCountryCode,
        KYCLEVEL newLevel,
        RISKSCOREBAND newRisk,
        INVESTORCLASS newClass
    ) external onlyOwner {
        if (_identities[user].verifiedTill == 0)
            revert IdentityDoesNotExist();

        Identity storage identity = _identities[user];

        identity.verifiedTill = newVerifiedTill;
        identity.identityURI = newIdentityURI;
        identity.countryCode = newCountryCode;
        identity.level = newLevel;
        identity.risk = newRisk;
        identity.class = newClass;

        emit IdentityUpdated(user);
    }

    /**
     * @notice Revokes an identity permanently.
     * @dev Only callable by the contract owner.
     */
    function revokeIdentity(address user) external onlyOwner {
        if (_identities[user].verifiedTill == 0)
            revert IdentityDoesNotExist();

        delete _identities[user];
        emit IdentityRevoked(user);
    }

    /*===============================GETTERS===============================*/

    /**
     * @notice Returns full identity data for a user.
     */
    function getIdentity(address user)
        external
        view
        returns (Identity memory)
    {
        if (_identities[user].verifiedTill == 0)
            revert IdentityDoesNotExist();

        return _identities[user];
    }
}

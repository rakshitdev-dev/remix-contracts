// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/**
 * @title IIdentityRegistry
 * @author Rakshit Kumar Singh
 * @notice Interface for IdentityRegistry contract
 *
 * @dev
 *  - Provides on-chain identity verification for RWA ecosystem.
 *  - Used by token, manager, and compliance contracts.
 */
interface IIdentityRegistry {
    /*===============================ENUMS===============================*/

    enum KYCLEVEL {
        none,
        basic,
        enhanced
    }

    enum RISKSCOREBAND {
        low,
        medium,
        high
    }

    enum IDENTITYTYPE {
        investor,
        owner
    }

    /*===============================STRUCTS===============================*/

    struct Identity {
        uint256 verifiedTill;
        string identityURI;
        string countryCode;
        KYCLEVEL level;
        RISKSCOREBAND risk;
        IDENTITYTYPE typ;
    }

    /*===============================EVENTS===============================*/

    event IdentityRegistered(
        address indexed user,
        uint256 verifiedTill,
        string countryCode,
        string identityURI,
        KYCLEVEL level,
        RISKSCOREBAND risk,
        IDENTITYTYPE typ
    );

    event IdentityUpdated(address indexed user);
    event IdentityRevoked(address indexed user);

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error IdentityAlreadyVerified();
    error IdentityDoesNotExist();
    error IdentityInvalid(address user);

    /*===============================VIEWS===============================*/

    function hasValidIdentity(address user) external view returns (bool);

    function getIdentity(address user)
        external
        view
        returns (Identity memory);

    function isInvestor(address user) external view returns (bool);

    function isPropertyOwner(address user) external view returns (bool);

    /*===============================ADMIN FUNCTIONS===============================*/

    function registerIdentity(
        address user,
        uint256 verifiedTill,
        string calldata identityURI,
        string calldata countryCode,
        KYCLEVEL level,
        RISKSCOREBAND risk,
        IDENTITYTYPE typ
    ) external;

    function updateIdentity(
        address user,
        uint256 newVerifiedTill,
        string calldata newIdentityURI,
        string calldata newCountryCode,
        KYCLEVEL newLevel,
        RISKSCOREBAND newRisk,
        IDENTITYTYPE newTyp
    ) external;

    function revokeIdentity(address user) external;
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title IIdentityRegistry
 * @author Rakshit Kumar Singh
 * @dev Interface MUST exactly match IdentityRegistry ABI.
 *
 *      - Used for identity and jurisdiction enforcement
 *      - Read-only access for external contracts
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

    enum INVESTORCLASS {
        retail,
        professional,
        accredited
    }

    /*===============================STRUCTS===============================*/

    struct Identity {
        uint256 verifiedTill;
        string identityURI;
        string countryCode;
        KYCLEVEL level;
        RISKSCOREBAND risk;
        INVESTORCLASS class;
    }

    /*===============================VIEWS===============================*/

    /**
     * @notice Returns true if the identity exists and is not expired.
     */
    function hasValidIdentity(address user) external view returns (bool);

    /**
     * @notice Returns full identity data for a user.
     */
    function getIdentity(
        address user
    ) external view returns (Identity memory);
}

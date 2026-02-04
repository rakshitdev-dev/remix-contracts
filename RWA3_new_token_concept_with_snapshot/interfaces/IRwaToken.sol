// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IIdentityRegistry} from "./IIdentityRegistry.sol";

/**
 * @title IRwaToken
 * @author Rakshit Kumar Singh
 * @dev Interface for RwaToken (EIP-1167 clone compatible)
 */
interface IRwaToken {
    /*===============================STRUCTS===============================*/

    struct InitParams {
        string name;
        string symbol;
        uint256 assetId;
        address identityRegistry;
        uint256 cap;
        uint256 price;
        address propertyManager;
    }

    /*===============================INITIALIZER===============================*/

    function initialize(InitParams calldata params) external;

    /*===============================ERC20 VIEW===============================*/

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
    function price() external view returns (uint256);
    /*===============================RWA VIEWS===============================*/

    function assetId() external view returns (uint256);
    function cap() external view returns (uint256);
    function identityRegistry() external view returns (IIdentityRegistry);

    /*===============================INVEST / ADMIN===============================*/

    function invest(address account, uint256 value) external payable;
    function setPrice(uint256 price) external;

    /*===============================OWNERSHIP===============================*/

    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;

    /*===============================EVENTS===============================*/

    event PriceChanged(uint256 oldPrice, uint256 newPrice);

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error InvalidDistribution();
    error IdentityRequired(address user);
    error CountryTransferBlocked(
        address from,
        address to,
        string fromCountry,
        string toCountry
    );
    error CapLimitVoilated(uint256 difference);
}

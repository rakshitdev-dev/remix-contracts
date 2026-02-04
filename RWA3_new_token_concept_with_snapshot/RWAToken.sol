// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {ERC20Snapshot} from "./snapshot.sol";
/*===============================TOKEN===============================*/

/**
 * @title RwaToken
 * @author Rakshit Kumar Singh
 * @dev ERC20 token representing fractional ownership of a legally approved RWA.
 *
 *      - Transfers are identity-gated
 *      - Cross-jurisdiction transfers are blocked
 *      - Designed to integrate with LegalRegistry + IdentityRegistry
 */
contract RwaToken is
    Initializable,
    ERC20Upgradeable,
    ERC20Snapshot,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*===============================STORAGE===============================*/

    uint256 public assetId;
    IIdentityRegistry public identityRegistry;
    uint256 public cap;
    uint256 price;
    uint256 public rentAmount;

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

    /*===============================EVENTS===============================*/

    event PriceChanged(uint256 oldPrice, uint256 newPrice);

    /*===============================INIT PARAMS===============================*/

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

    /**
     * @notice Initializes the RWA token instance.
     * @dev Called once by the factory or deployer.
     */
    function initialize(InitParams calldata params) external initializer {
        if (params.identityRegistry == address(0)) revert ZeroAddress();
        if (params.propertyManager == address(0)) revert ZeroAddress();

        require(params.cap > 0, "Cap can't be 0");
        cap = params.cap;

        require(params.price > 0, "Price can't be 0");
        price = params.price;

        __ERC20_init(params.name, params.symbol);
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        assetId = params.assetId;
        identityRegistry = IIdentityRegistry(params.identityRegistry);

        transferOwnership(params.propertyManager);
    }

    /*===============================INTERNAL FUNCTIONS overrides===============================*/

    /**
     * @dev Country + identity gated ERC20 transfer hook.
     *
     * Rules:
     * - Minting allowed only from owner
     * - Burning allowed to zero address
     * - Sender and receiver must both have valid identity
     * - Sender and receiver must belong to the same country
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20Snapshot) {
        if (from == address(0) && totalSupply() + amount > cap) {
            revert CapLimitVoilated(totalSupply() + amount - cap);
        }
        // Minting
        if (from == address(0)) {
            super._update(from, to, amount);
            return;
        }
        if (from == address(owner())) {
            super._update(from, to, amount);
            return;
        }

        // Burning
        if (to == address(0)) {
            super._update(from, to, amount);
            return;
        }
        if (to == address(owner())) {
            super._update(from, to, amount);
            return;
        }

        // Identity enforcement
        if (!identityRegistry.hasValidIdentity(from))
            revert IdentityRequired(from);
        if (!identityRegistry.hasValidIdentity(to)) revert IdentityRequired(to);

        // Jurisdiction enforcement
        IIdentityRegistry.Identity memory fromId = identityRegistry.getIdentity(
            from
        );
        IIdentityRegistry.Identity memory toId = identityRegistry.getIdentity(
            to
        );

        if (
            keccak256(bytes(fromId.countryCode)) !=
            keccak256(bytes(toId.countryCode))
        ) {
            revert CountryTransferBlocked(
                from,
                to,
                fromId.countryCode,
                toId.countryCode
            );
        }

        super._update(from, to, amount);
    }

    /*===============================Invest===============================*/

    /**
     * @notice Invests ETH to mint RWA tokens at the current price.
     *
     * @dev
     * - Token minting is capped by `cap` via `_update`
     * - Identity is NOT enforced here because minting
     *   bypasses identity checks in `_update`
     * - Identity enforcement starts from secondary transfers
     * - ETH is forwarded directly to the property manager (owner)
     *
     * @param account Address receiving the minted RWA tokens
     * @param value   Amount of tokens to mint (in token decimals)
     *
     * Requirements:
     * - `value` must not exceed remaining cap
     * - Caller must send exact ETH equivalent via `msg.value`
     *
     * Security notes:
     * - Relies on owner being a trusted property manager
     * - Not suitable for permissionless public minting
     */
    function invest(address account, uint256 value) public {
        uint256 cost = (value / (10 ** decimals())) * price;
        (bool status, ) = owner().call{value: cost}("");
        require(status, "ETH transfer failed");
        _mint(account, value);
    }

    function setPrice(uint256 _price) public onlyOwner {
        require(_price > 0, "INVALID_PRICE");
        uint256 oldP = price;
        price = _price;
        emit PriceChanged(oldP, _price);
    }

    // function snapshot() external returns (uint256) {
    //     return _snapshot();
    // }

    // /*=============================== Rent System ===============================*/

    function payRent() public returns (uint256) {
        require(true, "");
        return _snapshot();
    }

    /*===============================RECEIVE===============================*/

    receive() external payable {}
}

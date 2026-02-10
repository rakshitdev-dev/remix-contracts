// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IRwaManager} from "./interfaces/IRwaManager.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {ILegalRegistry} from "./interfaces/ILegalRegistry.sol";
import {ERC20Snapshot} from "./Snapshot.sol";
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
    uint256 public cap;
    uint256 public price;
    uint256 public rentAmount;
    mapping(uint256 => uint256) rentCollection;
    mapping(uint256 => mapping(address => bool)) public rentCollectionStatus;
    mapping(uint256 => uint256) public supplyAtSnapshot;
    mapping(uint256 => uint256) public periodToSnapshot;
    mapping(uint256 => uint256) public snapshotToPeriod;

    IRwaManager managerContract;

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
    error AlreadyClaimed();
    error NoRentAvailable();

    /*===============================EVENTS===============================*/

    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event RentClaimed(uint256 period, address receiver, uint256 payout);

    /*===============================INIT PARAMS===============================*/

    struct InitParams {
        string name;
        string symbol;
        uint256 assetId;
        address managerContract;
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
        if (params.managerContract == address(0)) revert ZeroAddress();
        if (params.propertyManager == address(0)) revert ZeroAddress();

        require(params.cap > 0, "Cap can't be 0");
        cap = params.cap;

        require(params.price > 0, "Price can't be 0");
        price = params.price;

        __ERC20_init(params.name, params.symbol);
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        assetId = params.assetId;
        managerContract = IRwaManager(params.managerContract);

        transferOwnership(params.propertyManager);
    }

    function _legalRegistry() internal view returns (ILegalRegistry) {
        return managerContract.legalRegistry();
    }

    function _identityRegistry() internal view returns (IIdentityRegistry) {
        return managerContract.identityRegistry();
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
        // Minting Cap
        require(_legalRegistry().isAssetApproved(assetId), "ASSET_NOT_APPROVED");
        if (from == address(0) && totalSupply() + amount > cap) {
            revert CapLimitVoilated(totalSupply() + amount - cap);
        }

        // // Minting
        // if (from == address(0)) {
        //     super._update(from, to, amount);
        //     return;
        // }
        // if (from == address(owner())) {
        //     super._update(from, to, amount);
        //     return;
        // }

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
        if (!_identityRegistry().hasValidIdentity(from))
            revert IdentityRequired(from);
        if (!_identityRegistry().hasValidIdentity(to))
            revert IdentityRequired(to);

        _legalRegistry().validateJurisdiction(from, assetId);
        _legalRegistry().validateJurisdiction(to, assetId);

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
    function invest(address account, uint256 value) external payable {
        _legalRegistry().validateJurisdiction(account, assetId);

        uint256 tokens = value / (10 ** decimals());
        uint256 cost = tokens * price;

        require(msg.value == cost, "INVALID_ETH_AMOUNT");

        (bool ok, ) = owner().call{value: msg.value}("");
        require(ok, "ETH_TRANSFER_FAILED");

        _mint(account, value);
    }

    function setPrice(uint256 _price) public onlyOwner {
        require(_price > 0, "INVALID_PRICE");
        uint256 oldP = price;
        price = _price;
        emit PriceChanged(oldP, _price);
    }

    function setRentAmount(uint256 amount) external onlyOwner {
        rentAmount = amount;
    }

    // function snapshot() external returns (uint256) {
    //     return _snapshot();
    // }

    // /*===============================Rent System===============================*/

    function payRent(
        uint16 year,
        uint8 month
    ) external payable onlyOwner returns (uint256 snapshotId) {
        require(msg.value >= rentAmount, "Insufficient Rent");
        require(month >= 1 && month <= 12, "Invalid Month");
        require(year >= 2000 && year <= 3000, "Invalid Year");

        uint256 periodId = year * 100 + month;
        require(periodToSnapshot[periodId] == 0, "Period rent paid");

        snapshotId = _snapshot();

        periodToSnapshot[periodId] = snapshotId;
        snapshotToPeriod[snapshotId] = periodId;

        rentCollection[snapshotId] = msg.value;
        supplyAtSnapshot[snapshotId] = totalSupply();

        return snapshotId;
    }

    function claimRent(
        uint256 snapshotId
    ) external nonReentrant returns (uint256 payout) {
        if (rentCollectionStatus[snapshotId][msg.sender])
            revert AlreadyClaimed();

        uint256 supply = supplyAtSnapshot[snapshotId];

        uint256 userBalance;

        if (msg.sender == owner()) userBalance = cap - supply;
        else userBalance = balanceOfAt(msg.sender, snapshotId);

        if (userBalance == 0) revert NoRentAvailable();

        uint256 totalRent = rentCollection[snapshotId];

        payout = (totalRent * userBalance) / cap;

        rentCollectionStatus[snapshotId][msg.sender] = true;

        (bool success, ) = msg.sender.call{value: payout}("");
        require(success, "Ether transfer failed");

        emit RentClaimed(snapshotToPeriod[snapshotId], msg.sender, payout);
    }

    /*===============================RECEIVE===============================*/

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
    
interface IRwaToken is IERC20MetadataUpgradeable{
    /* ============================== ERRORS ============================== */

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

    /* ============================== EVENTS ============================== */

    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event RentClaimed(uint256 period, address receiver, uint256 payout);

    /* ============================== STRUCTS ============================== */

    struct InitParams {
        string name;
        string symbol;
        uint256 assetId;
        address managerContract;
        uint256 cap;
        uint256 price;
        address propertyManager;
    }

    /* ============================== INITIALIZER ============================== */

    function initialize(InitParams calldata params) external;

    /* ============================== CORE TOKEN STATE ============================== */

    function assetId() external view returns (uint256);
    function cap() external view returns (uint256);
    function price() external view returns (uint256);
    function rentAmount() external view returns (uint256);
    function tenant() external view returns (address);

    /* ============================== RENT STORAGE ============================== */

    function rentCollection(uint256 snapshotId) external view returns (uint256);

    function rentCollectionStatus(
        uint256 snapshotId,
        address user
    ) external view returns (bool);

    function supplyAtSnapshot(
        uint256 snapshotId
    ) external view returns (uint256);

    function periodToSnapshot(uint256 periodId) external view returns (uint256);

    function snapshotToPeriod(
        uint256 snapshotId
    ) external view returns (uint256);

    /* ============================== INVEST ============================== */

    function invest(address account, uint256 buyAmount) external payable;

    /* ============================== ADMIN ============================== */

    function setPrice(uint256 _price) external;

    function setRentDetails(uint256 newRentAmount, address newTenant) external;

    /* ============================== RENT FLOW ============================== */

    function payRent(
        uint256 year,
        uint256 month
    ) external payable returns (uint256 snapshotId);

    function claimRent(uint256 snapshotId) external returns (uint256 payout);

    function totalSnapshots() external view returns (uint256);

    function owner() external view returns (address);

    /* ============================== ERC20 SNAPSHOT ============================== */
    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) external view returns (uint256);
}

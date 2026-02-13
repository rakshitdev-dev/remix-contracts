// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IRwaToken {
    /* ============================== EVENTS ============================== */

    event PriceChanged(uint256 oldPrice, uint256 newPrice);

    event RentClaimed(
        uint256 period, // YYYYMM
        address receiver,
        uint256 payout
    );

    /* ============================== INIT PARAMS ============================== */

    struct InitParams {
        string name;
        string symbol;
        uint256 assetId;
        address managerContract;
        uint256 cap;
        uint256 price;
        address propertyManager;
    }

    /* ============================== VIEW FUNCTIONS ============================== */

    function assetId() external view returns (uint256);

    function cap() external view returns (uint256);

    function price() external view returns (uint256);

    function rentAmount() external view returns (uint256);

    function managerContract() external view returns (address);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function owner() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) external view returns (uint256);

    function supplyAtSnapshot(
        uint256 snapshotId
    ) external view returns (uint256);

    function periodToSnapshot(uint256 period) external view returns (uint256);

    function snapshotToPeriod(
        uint256 snapshotId
    ) external view returns (uint256);

    function rentCollectionStatus(
        uint256 snapshotId,
        address user
    ) external view returns (bool);

    /* ============================== UPGRADEABLE ============================== */

    function initialize(InitParams calldata params) external;

    /* ============================== MUTATIVE FUNCTIONS ============================== */

    /**
     * @notice Invest ETH and mint RWA tokens
     * @param account receiver of tokens
     * @param value token amount (18 decimals)
     */
    function invest(address account, uint256 value) external payable;

    /**
     * @notice Owner sets token price
     */
    function setPrice(uint256 newPrice) external;

    /**
     * @notice Owner sets minimum rent amount
     */
    function setRentAmount(uint256 amount) external;

    /**
     * @notice Owner pays rent and creates snapshot
     * @param year YYYY
     * @param month 1–12
     * @return snapshotId created snapshot
     */
    function payRent(
        uint256 year,
        uint256 month
    ) external payable returns (uint256 snapshotId);

    /**
     * @notice Claim rent for a snapshot
     * @param snapshotId snapshot identifier
     * @return payout ETH amount received
     */
    function claimRent(uint256 snapshotId) external returns (uint256 payout);

    /**
     * @notice ERC20 transfer
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @notice ERC20 transferFrom
     * @param from token sender
     * @param to token receiver
     * @param value token amount
     * @return success true if transfer succeeds
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

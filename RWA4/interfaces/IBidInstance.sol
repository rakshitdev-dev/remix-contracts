// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBidContract {
    /*===============================CONSTANTS===============================*/

    function DEPOSIT_PERCENT() external view returns (uint256);

    /* ============================== INIT PARAMS ============================== */
    struct InitParams {
        address seller;
        address managerContract;
        uint256 rewardAmount;
        address priceToken;
        uint256 minTotalBid;
        uint256 duration;
        uint256 assetId;
        uint256 gracePeriod;
        uint256 feeBps;
    }

    /*===============================AUCTION CONFIG===============================*/

    function seller() external view returns (address);
    function managerContract() external view returns (address);
    function assetId() external view returns (uint256);
    function rewardAmount() external view returns (uint256);
    function priceToken() external view returns (IERC20);
    function minTotalBid() external view returns (uint256);
    function endTime() external view returns (uint256);
    function gracePeriodEnd() external view returns (uint256);
    function feeBps() external view returns (uint256);

    /*===============================AUCTION STATE===============================*/

    function highestBidder() external view returns (address);
    function highestDeposit() external view returns (uint256);
    function settled() external view returns (bool);
    function fullyPaid() external view returns (bool);
    function deposits(address user) external view returns (uint256);

    /*===============================INITIALIZER===============================*/

    function initialize(InitParams calldata params) external;

    /*===============================VIEWS===============================*/

    function isNativeAuction() external view returns (bool);

    function totalBid(uint256 deposit) external pure returns (uint256);

    function remainingPayment() external view returns (uint256);

    /*===============================BIDDING===============================*/

    function bidNative() external payable;

    function bidERC20(uint256 deposit) external;

    /*===============================PAYMENT===============================*/

    function payRemaining() external payable;

    /*===============================WITHDRAW===============================*/

    function withdraw() external;

    /*===============================SETTLEMENT===============================*/

    function settle() external;

    /*===============================EVENTS===============================*/

    event BidPlaced(address indexed bidder, uint256 deposit);

    event RemainingPaid(address indexed bidder, uint256 amount);

    event DepositWithdrawn(address indexed bidder, uint256 amount);

    event DepositForfeited(address indexed bidder, uint256 amount);

    event AuctionSettled(address winner, uint256 totalBid);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRwaManager} from "./IRwaManager.sol";

/**
 * @title IBidContract
 * @author Rakshit Kumar Singh
 * @notice Interface for English-style RWA auction with 10% deposit mechanism
 */
interface IBidContract {
    /*===============================CONSTANTS===============================*/

    /// @notice Fixed deposit percentage (10%)
    function DEPOSIT_PERCENT() external pure returns (uint256);

    /*===============================AUCTION CONFIG===============================*/

    /// @notice Address receiving auction proceeds
    function seller() external view returns (address);

    /// @notice RWA manager contract
    function manager() external view returns (IRwaManager);

    /// @notice Asset identifier
    function assetId() external view returns (uint256);

    /// @notice Amount of RWA tokens rewarded to winner
    function rewardAmount() external view returns (uint256);

    /// @notice ERC20 bidding token (address(0) for native ETH)
    function bidToken() external view returns (IERC20);

    /// @notice Minimum allowed total bid (100%)
    function minTotalBid() external view returns (uint256);

    /// @notice Auction end timestamp
    function endTime() external view returns (uint256);

    /// @notice Grace period end timestamp
    function gracePeriodEnd() external view returns (uint256);

    /// @notice Platform fee in basis points
    function feeBps() external view returns (uint256);

    /*===============================AUCTION STATE===============================*/

    /// @notice Current highest bidder
    function highestBidder() external view returns (address);

    /// @notice Deposit amount of highest bidder (10%)
    function highestDeposit() external view returns (uint256);

    /// @notice Whether auction has been settled
    function settled() external view returns (bool);

    /// @notice Whether winner completed remaining payment
    function fullyPaid() external view returns (bool);

    /// @notice Returns deposited amount for a bidder
    function deposits(address bidder) external view returns (uint256);

    /*===============================EVENTS===============================*/

    event BidPlaced(address indexed bidder, uint256 deposit);
    event RemainingPaid(address indexed bidder, uint256 amount);
    event DepositWithdrawn(address indexed bidder, uint256 amount);
    event DepositForfeited(address indexed bidder, uint256 amount);
    event AuctionSettled(address winner, uint256 totalBid);

    /*===============================VIEWS===============================*/

    /// @notice Returns true if auction uses native ETH
    function isNativeAuction() external view returns (bool);

    /// @notice Converts deposit (10%) to total bid (100%)
    function totalBid(uint256 deposit) external pure returns (uint256);

    /// @notice Remaining payment required from winner
    function remainingPayment() external view returns (uint256);

    /*===============================BIDDING===============================*/

    /// @notice Place or increase bid using native ETH
    function bidNative() external payable;

    /// @notice Place or increase bid using ERC20 token
    function bidERC20(uint256 deposit) external;

    /*===============================PAYMENT===============================*/

    /// @notice Winner pays remaining 90% of bid
    function payRemaining() external payable;

    /*===============================WITHDRAW===============================*/

    /// @notice Withdraw refundable deposit if not highest bidder
    function withdraw() external;

    /*===============================SETTLEMENT===============================*/

    /// @notice Finalizes auction and distributes funds
    function settle() external;
}
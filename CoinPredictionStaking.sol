// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title CoinPrediction
/// @notice Users stake tokens and earn apr (specified in basis points).
/// @author Rakshit Kumar Singh
contract CoinPredictionStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public owner;
    bool public unlocked = true;

    // uint256 public constant YEAR = 365 days;
    uint256 public constant YEAR = 365; // Value for testing
    uint256 public maxStakeDuration;
    uint256 public minStakeDuration;

    // apr stored in basis points (e.g. 1000 = 10%)
    uint256 public apr;

    // Track total currently staked to protect withdrawals
    uint256 public totalStaked;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 claimedRewards;
        bool active;
        uint256 stakeApr; // @dev for a perticular stake apr remains constant changes will be applied on later stakes
    }

    struct PendingReward {
        bool stakeStatus;
        bool unstakable;
        uint256 pendingReward;
    }

    mapping(address => Stake[]) private stakes;

    event Staked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event LockToggled(bool unlocked);
    event AprUpdated(uint256 newApr);
    event MinDurationUpdated(uint256 minYears);
    event MaxDurationUpdated(uint256 maxYears);
    event WithdrawnUnused(address indexed owner, uint256 amount);

    constructor(
        IERC20 tokenAddress,
        uint256 initialMinDurationYears,
        uint256 initialMaxDurationYears,
        uint256 initialApr
    ) {
        token = tokenAddress;
        owner = msg.sender;
        minStakeDuration = initialMinDurationYears * YEAR;
        maxStakeDuration = initialMaxDurationYears * YEAR;
        apr = initialApr; // @dev 100 basis point
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @dev validate that index exists for a given user
    modifier validateIndex(address user, uint256 index) {
        require(index < stakes[user].length, "Invalid index");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function toggleLock() external onlyOwner {
        unlocked = !unlocked;
        emit LockToggled(unlocked);
    }

    function stake(uint256 amount) external nonReentrant {
        require(unlocked, "Staking paused");
        require(amount > 0, "Invalid amount");

        token.safeTransferFrom(msg.sender, address(this), amount);

        stakes[msg.sender].push(
            Stake({
                amount: amount,
                startTime: block.timestamp,
                claimedRewards: 0,
                active: true,
                stakeApr: apr
            })
        );

        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function getUserPendingReward(
        address user
    ) external view returns (PendingReward[] memory) {
        Stake[] storage userStakes = stakes[user];
        uint256 count = userStakes.length;

        PendingReward[] memory infoArray = new PendingReward[](count);

        for (uint256 i = 0; i < count; ) {
            Stake storage stakeData = userStakes[i];

            infoArray[i] = PendingReward({
                stakeStatus: stakeData.active,
                unstakable: block.timestamp >=
                    stakeData.startTime + minStakeDuration,
                pendingReward: pendingRewards(user, i)
            });

            unchecked {
                ++i;
            }
        }

        return infoArray;
    }

    /// @dev Calculate pending rewards (based on completed full years)
    function pendingRewards(
        address user,
        uint256 index
    ) private view validateIndex(user, index) returns (uint256) {
        Stake memory s = stakes[user][index];
        if (!s.active) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        if (elapsed > maxStakeDuration) elapsed = maxStakeDuration;

        // s.stakeApr is basis points; divide by 10000 to get fraction
        uint256 totalReward = (s.amount * elapsed * s.stakeApr) /
            (YEAR * 10000);

        if (totalReward <= s.claimedRewards) return 0;
        return totalReward - s.claimedRewards;
    }

    function claimReward(
        uint256 index
    ) external nonReentrant validateIndex(msg.sender, index) {
        require(unlocked, "Staking paused");
        uint256 reward = pendingRewards(msg.sender, index);
        require(reward > 0, "No rewards yet");

        stakes[msg.sender][index].claimedRewards += reward;
        token.safeTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function unstake(
        uint256 index
    ) external nonReentrant validateIndex(msg.sender, index) {
        require(unlocked, "Staking paused");
        Stake memory s = stakes[msg.sender][index];
        require(s.active, "Already unstaked");

        uint256 elapsed = block.timestamp - s.startTime;
        require(elapsed >= minStakeDuration, "Minimum time not passed yet");

        uint256 reward = pendingRewards(msg.sender, index);
        uint256 totalReturn = s.amount + reward;

        // mark inactive and update totalStaked
        stakes[msg.sender][index].active = false;
        stakes[msg.sender][index].claimedRewards += reward; 
        totalStaked -= s.amount;

        token.safeTransfer(msg.sender, totalReturn);

        emit Unstaked(msg.sender, s.amount, reward);
    }

    /// @dev Owner may withdraw only tokens in excess of currently staked amount
    function withdrawUnusedTokens() external onlyOwner {
        uint256 bal = token.balanceOf(address(this));
        require(bal > totalStaked, "No excess tokens");
        uint256 withdrawAmount = bal - totalStaked;
        token.safeTransfer(msg.sender, withdrawAmount);
        emit WithdrawnUnused(msg.sender, withdrawAmount);
    }

    function getUserStakesCount(address user) external view returns (uint256) {
        return stakes[user].length;
    }

    function setMinDuration(uint256 newMinDurationYears) public onlyOwner {
        minStakeDuration = newMinDurationYears * YEAR;
        emit MinDurationUpdated(newMinDurationYears);
    }

    function setMaxDuration(uint256 newMaxDurationYears) public onlyOwner {
        maxStakeDuration = newMaxDurationYears * YEAR;
        emit MaxDurationUpdated(newMaxDurationYears);
    }

    // apr supplied in basis points (1000 = 10%)
    function setApr(uint256 newAprBasisPoints) public onlyOwner {
        apr = newAprBasisPoints;
        emit AprUpdated(newAprBasisPoints);
    }

    function getUserStakes(
        address user
    ) external view returns (Stake[] memory) {
        return stakes[user];
    }
}

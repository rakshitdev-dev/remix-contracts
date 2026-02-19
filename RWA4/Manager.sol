// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {ILegalRegistry} from "./interfaces/ILegalRegistry.sol";
import {IRwaToken} from "./interfaces/IRwaToken.sol";
import {IBidContract} from "./interfaces/IBidInstance.sol";
/*===============================MANAGER===============================*/

/**
 * @title RwaManager
 * @author Rakshit Kumar Singh
 * @dev Deploys and manages RWA ERC20 token instances (EIP-1167).
 *
 *      - Enforces legal approval via LegalRegistry
 *      - Enforces jurisdiction + identity compliance
 *      - One token per approved asset
 */
contract RwaManager is Ownable {
    using Clones for address;

    struct RwaInfo {
        uint256 assetId;
        address token;
        string name;
        string symbol;
        uint256 cap;
        uint256 price;
        address propertyManager;
        uint256 totalSupply;
        ILegalRegistry.AssetStatus status;
        string documentURI;
        string[] countryCodes;
        address legalPropertyOwner;
        uint256 rentAmount;
        address tenant;
    }

    /*===============================RWA STORAGE===============================*/

    /// @dev RWA token implementation (EIP-1167)
    address public rwaImplementation;

    // @dev Bidding implementation for rwa tokens
    address public bidImplementation;

    /// @dev External registries
    ILegalRegistry public immutable legalRegistry;
    IIdentityRegistry public immutable identityRegistry;

    /// @dev AssetId => RWA token
    mapping(uint256 => address) public rwaByAsset;

    /// @dev List of all deployed RWA tokens
    address[] private allRWATokens;

    /// @dev Total deployed RWAs
    uint256 public totalRWAs;

    uint256 bidFee;

    /*===============================BID STORAGE===============================*/

    struct BidInfo {
        address bidContract;
        address seller;
        address managerContract;
        uint256 assetId;
        uint256 rewardAmount;
        address priceToken;
        uint256 minTotalBid;
        uint256 endTime;
        uint256 gracePeriodEnd;
        uint256 feeBps;
        address highestBidder;
        uint256 highestDeposit;
        bool settled;
        bool fullyPaid;
        bool isNativeAuction;
        uint256 remainingPayment;
    }

    /// @dev List of all bid Contracts
    address[] public allBids;
    mapping(address => bool) public isBidContract;

    uint256 bidGracePeriod;

    /*===============================EVENTS===============================*/

    event RWACreated(uint256 indexed assetId, address indexed token);
    event RwaImplementationUpdated(
        address indexed oldImpl,
        address indexed newImpl
    );
    event BidImplementationUpdated(
        address indexed oldImpl,
        address indexed newImpl
    );
    event BidGracePeriodUpdated(uint256 oldTime, uint256 newTime);
    event BidFeeUpdated(uint256 oldFee, uint256 newFee);
    event BidCreated(
        uint256 indexed bidId,
        uint256 indexed assetId,
        address indexed bidContract,
        address creator
    );

    /*===============================ERRORS===============================*/

    error ZeroAddress();
    error AssetNotApproved();
    error AlreadyTokenized();
    error InvalidDistribution();
    error InvalidAddress();
    error IdentityMissing(address user);
    error CountryMismatch(
        address user,
        string identityCountry,
        string assetCountry
    );

    /*===============================CONSTRUCTOR===============================*/

    constructor(
        address identityRegistry_,
        address legalRegistry_,
        address rwaImplementation_,
        address bidImplementation_,
        uint256 bidGracePeriod_,
        uint256 bidFee_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            rwaImplementation_ == address(0) ||
            legalRegistry_ == address(0) ||
            identityRegistry_ == address(0)
        ) revert ZeroAddress();

        identityRegistry = IIdentityRegistry(identityRegistry_);
        legalRegistry = ILegalRegistry(legalRegistry_);
        rwaImplementation = rwaImplementation_;
        bidImplementation = bidImplementation_;
        bidGracePeriod = bidGracePeriod_;
        bidFee = bidFee_;
    }

    /*=====================================================================
                                RWA MANAGEMENT
    =====================================================================*/

    /*===============================ADMIN===============================*/

    function updateRwaImplementation(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        address old = rwaImplementation;
        rwaImplementation = newImpl;
        emit RwaImplementationUpdated(old, newImpl);
    }

    function updateBidImplementation(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert ZeroAddress();
        address old = bidImplementation;
        bidImplementation = newImpl;
        emit BidImplementationUpdated(old, newImpl);
    }

    function updateBidGracePeriod(
        uint256 newBidGracePeriod
    ) external onlyOwner {
        uint256 old = bidGracePeriod;
        bidGracePeriod = newBidGracePeriod;
        emit BidGracePeriodUpdated(old, newBidGracePeriod);
    }

    function updateBidFee(uint256 newBidFee) external onlyOwner {
        uint256 old = bidGracePeriod;
        bidFee = newBidFee;
        emit BidFeeUpdated(old, newBidFee);
    }

    /*===============================CORE LOGIC===============================*/

    /**
     * @notice Creates and initializes an RWA token for an approved asset.
     */
    function createRwa(
        string calldata name,
        string calldata symbol,
        uint256 assetId,
        uint256 cap,
        uint256 price
    ) external returns (address token) {
        /* ---------- Legal Approval ---------- */
        if (!legalRegistry.isAssetApproved(assetId)) revert AssetNotApproved();
        if (rwaByAsset[assetId] != address(0)) revert AlreadyTokenized();

        /* ---------- Fetch Asset ---------- */
        (
            address propertyOwner,
            ,
            ,
            ILegalRegistry.AssetStatus status
        ) = legalRegistry.getAsset(assetId);

        if (propertyOwner == address(0)) revert ZeroAddress();
        require(
            _msgSender() == propertyOwner || _msgSender() == owner(),
            "Only Admin or Property Owner"
        );

        if (status != ILegalRegistry.AssetStatus.APPROVED)
            revert AssetNotApproved();

        /* ---------- Identity & Jurisdiction ---------- */
        if (!identityRegistry.hasValidIdentity(propertyOwner))
            revert IdentityMissing(propertyOwner);

        // Validate jurisdiction against LegalRegistry rules
        legalRegistry.validateJurisdiction(propertyOwner, assetId);

        /* ---------- Parameters ---------- */
        if (cap == 0) revert InvalidDistribution();
        if (price == 0) revert InvalidDistribution();

        /* ---------- Deploy Clone ---------- */
        token = rwaImplementation.clone();

        IRwaToken.InitParams memory params = IRwaToken.InitParams({
            name: name,
            symbol: symbol,
            assetId: assetId,
            managerContract: address(this),
            cap: cap,
            price: price,
            propertyManager: propertyOwner
        });

        IRwaToken(token).initialize(params);

        rwaByAsset[assetId] = token;
        allRWATokens.push(token);
        totalRWAs++;

        emit RWACreated(assetId, token);
    }

    /*===============================VIEWS===============================*/

    /**
     * @notice Returns all deployed RWA token addresses.
     */
    function getAllRWATokens() external view returns (address[] memory) {
        return allRWATokens;
    }

    /**
     * @notice Paginated access to deployed RWA tokens.
     */
    function getRWATokens(
        uint256 page,
        uint256 limit
    ) external view returns (address[] memory result) {
        uint256 total = allRWATokens.length;
        uint256 start = page * limit;
        if (start >= total) return new address[](0);

        uint256 end = start + limit;
        if (end > total) end = total;

        result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = allRWATokens[i];
        }
    }

    function getAllRWAsWithData()
        public
        view
        returns (RwaInfo[] memory result)
    {
        return getRWAsWithData(0, allRWATokens.length);
    }

    function getRWAsWithData(
        uint256 page,
        uint256 limit
    ) public view returns (RwaInfo[] memory result) {
        uint256 total = allRWATokens.length;
        uint256 start = page * limit;

        if (start >= total) return new RwaInfo[](0);

        uint256 end = start + limit;
        if (end > total) end = total;

        result = new RwaInfo[](end - start);

        for (uint256 i = start; i < end; i++) {
            address tokenAddr = allRWATokens[i];
            IRwaToken rwa = IRwaToken(tokenAddr);

            uint256 assetId = rwa.assetId();

            (
                address legalOwner,
                string[] memory countryCodes,
                string memory documentURI,
                ILegalRegistry.AssetStatus status
            ) = legalRegistry.getAsset(assetId);

            result[i - start] = RwaInfo({
                token: tokenAddr,
                assetId: assetId,
                name: rwa.name(),
                symbol: rwa.symbol(),
                cap: rwa.cap(),
                price: rwa.price(),
                propertyManager: rwa.owner(),
                totalSupply: rwa.totalSupply(),
                status: status,
                documentURI: documentURI,
                countryCodes: countryCodes,
                legalPropertyOwner: legalOwner,
                rentAmount: rwa.rentAmount(),
                tenant: rwa.tenant()
            });
        }
    }

    function getRwaWithDataByAssetId(
        uint256 assetId
    ) public view returns (RwaInfo memory result) {
        address tokenAddr = rwaByAsset[assetId];
        if (tokenAddr == address(0)) revert ZeroAddress();

        IRwaToken rwa = IRwaToken(tokenAddr);

        (
            address legalOwner,
            string[] memory countryCodes,
            string memory documentURI,
            ILegalRegistry.AssetStatus status
        ) = legalRegistry.getAsset(assetId);

        result = RwaInfo({
            token: tokenAddr,
            assetId: assetId,
            name: rwa.name(),
            symbol: rwa.symbol(),
            cap: rwa.cap(),
            price: rwa.price(),
            propertyManager: rwa.owner(),
            totalSupply: rwa.totalSupply(),
            status: status,
            documentURI: documentURI,
            countryCodes: countryCodes,
            legalPropertyOwner: legalOwner,
            rentAmount: rwa.rentAmount(),
            tenant: rwa.tenant()
        });
    }

    /*=====================================================================
                                BID MANAGEMENT
    =====================================================================*/

    function createBid(
        uint256 assetId,
        uint256 rewardAmount,
        uint256 minTotalBid,
        uint256 duration,
        address priceToken
    ) external returns (address bidAddress) {
        if (bidImplementation == address(0)) revert ZeroAddress();

        IIdentityRegistry.Identity memory sellerIdentiy = identityRegistry
            .getIdentity(msg.sender);

        uint256 requiredTime = duration + bidGracePeriod;

        require(
            sellerIdentiy.verifiedTill > (block.timestamp + requiredTime),
            "Manager: IDENTITY_LIMIT_ERROR"
        );

        bidAddress = bidImplementation.clone();

        IBidContract.InitParams memory params = IBidContract.InitParams({
            seller: msg.sender,
            managerContract: address(this),
            rewardAmount: rewardAmount,
            priceToken: priceToken,
            minTotalBid: minTotalBid,
            duration: duration,
            assetId: assetId,
            gracePeriod: bidGracePeriod,
            feeBps: bidFee
        });

        IBidContract(bidAddress).initialize(params);

        address rwa = rwaByAsset[assetId];

        uint256 bidId = allBids.length;
        allBids.push(bidAddress);
        isBidContract[bidAddress] = true;

        require(
            IRwaToken(rwa).transferFrom(msg.sender, bidAddress, rewardAmount),
            "Reward escrow transfer failed"
        );

        emit BidCreated(bidId, assetId, bidAddress, msg.sender);
    }

    function getBidInfoByAddress(
        address bidAddress
    ) public view returns (BidInfo memory info) {
        if (bidAddress == address(0)) revert ZeroAddress();

        IBidContract bid = IBidContract(bidAddress);

        if (bid.managerContract() != address(this)) {
            revert InvalidAddress();
        }

        info = BidInfo({
            bidContract: bidAddress,
            seller: bid.seller(),
            managerContract: address(this),
            assetId: bid.assetId(),
            rewardAmount: bid.rewardAmount(),
            priceToken: address(bid.priceToken()),
            minTotalBid: bid.minTotalBid(),
            endTime: bid.endTime(),
            gracePeriodEnd: bid.gracePeriodEnd(),
            feeBps: bid.feeBps(),
            highestBidder: bid.highestBidder(),
            highestDeposit: bid.highestDeposit(),
            settled: bid.settled(),
            fullyPaid: bid.fullyPaid(),
            isNativeAuction: bid.isNativeAuction(),
            remainingPayment: bid.remainingPayment()
        });
    }

    function getBidInfoById(
        uint256 bidId
    ) public view returns (BidInfo memory info) {
        if (bidId >= allBids.length) revert ILegalRegistry.InvalidId();
        return getBidInfoByAddress(allBids[bidId]);
    }

    function getBidsInfo(
        uint256 page,
        uint256 limit
    ) public view returns (BidInfo[] memory result) {
        uint256 total = allBids.length;
        uint256 start = page * limit;

        if (start >= total) return new BidInfo[](0);

        uint256 end = start + limit;
        if (end > total) end = total;

        result = new BidInfo[](end - start);

        for (uint256 i = start; i < end; i++) {
            address bidAddr = allBids[i];
            result[i - start] = getBidInfoByAddress(bidAddr);
        }
    }

    function getAllBidsInfo() public view returns (BidInfo[] memory result) {
        return getBidsInfo(0, allBids.length);
    }

    /*===============================ETH HANDLING===============================*/

    receive() external payable {}
    fallback() external payable {}
}
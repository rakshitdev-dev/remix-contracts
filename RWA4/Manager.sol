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

    /*===============================BID STORAGE===============================*/

    struct BidInfo {
        uint256 bidId;
        uint256 assetId;
        address bidContract;
        address creator;
        address seller;
        address bidToken;
        uint256 rewardAmount;
        uint256 minTotalBid;
        uint256 duration;
        uint256 gracePeriod;
        uint256 feeBps;
        uint256 createdAt;
    }

    /// @dev Incremental bid ID
    uint256 public totalBids;

    /// @dev assetId => bidIds
    mapping(uint256 => uint256[]) private _bidsByAsset;

    /// @dev creator => bidIds
    mapping(address => uint256[]) private _bidsByCreator;

    /// @dev List of all bid IDs
    uint256[] private _allBidIds;

    uint256 bidGracePeriod;

    /*===============================EVENTS===============================*/

    event RWACreated(uint256 indexed assetId, address indexed token);
    event RwaImplementationUpdated(
        address indexed oldImpl,
        address indexed newImpl
    );

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
            propertyOwner != _msgSender() || owner() != _msgSender(),
            "Only Admin or a Property Owner could create"
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
                legalPropertyOwner: legalOwner
            });
        }
    }

    /*=====================================================================
                                BID MANAGEMENT
    =====================================================================*/

    function createBid(
        uint256 assetId,
        uint256 rewardAmount,
        uint256 minTotalBid,
        uint256 duration,
        uint256 feeBps
    ) external returns (uint256 bidId, address bidAddress) {
        if (bidImplementation == address(0)) revert ZeroAddress();

        IIdentityRegistry.Identity memory sellerIdentiy = identityRegistry
            .getIdentity(msg.sender);

        uint256 requiredTime = duration + bidGracePeriod;

        require(
            sellerIdentiy.verifiedTill > (block.timestamp + requiredTime),
            "Manager: IDENTITY_LIMIT_ERROR"
        );
        
        address rwa = rwaByAsset[assetId];
        if (rwa == address(0)) revert AssetNotApproved();

        address bidToken = allRWATokens[assetId];

        IBidContract.InitParams memory params = IBidContract.InitParams({
            seller: msg.sender,
            managerContract: address(this),
            rewardAmount: rewardAmount,
            bidToken: bidToken,
            minTotalBid: minTotalBid,
            duration: duration,
            assetId: assetId,
            gracePeriod: bidGracePeriod,
            feeBps: feeBps
        });

        IBidContract(bidAddress).initialize(params);

        bidId = ++totalBids;

        _bidsByAsset[assetId].push(bidId);
        _bidsByCreator[msg.sender].push(bidId);
        _allBidIds.push(bidId);

        emit BidCreated(bidId, assetId, bidAddress, msg.sender);
    }

    /*===============================ETH HANDLING===============================*/

    receive() external payable {}
    fallback() external payable {}
}

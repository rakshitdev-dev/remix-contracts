// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Web3Market is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    error TransferFailed(address to, uint256 amount);

    uint public constant VERSION = 1;

    uint256 public itemCount;
    address public feeReceiverAddress;
    uint256 public createFee;
    uint256 public buyFeePercent;

    mapping(uint256 => Item) public items;
    mapping(uint256 => mapping(address => uint256)) public itemPrice;
    mapping(uint256 => ItemDiscount) public itemDiscounts;
    mapping(address => uint256[]) public ownerItems;
    mapping(address => uint256[]) public purchaseItems;
    mapping(uint256 => mapping(address => bool)) public isBoughtBy;

    struct Item {
        string name;
        address owner;
        uint256 price;
    }

    struct ItemDiscount {
        uint256 percent;
        uint256 expiration;
    }

    event ItemCreated(
        uint256 indexed id,
        address indexed owner,
        string name,
        address token,
        uint256 price
    );
    event ItemPriceUpdated(uint256 indexed id, address token, uint256 price);
    event ItemPurchased(
        uint256 indexed id,
        address indexed owner,
        address buyer,
        address token,
        uint256 price
    );
    event FeeReceiverAddressUpdated(address newReceiver);
    event CreateFeeUpdated(uint256 newFee);
    event BuyFeeUpdated(uint256 newFeePercent);
    event ItemDiscountSet(uint256 indexed id, uint256 percent, uint256 expiration);

    function initialize(
        uint256 _createFee,
        uint256 _buyFeePercent,
        address _feeReceiverAddress
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        createFee = _createFee;
        buyFeePercent = _buyFeePercent;
        feeReceiverAddress = _feeReceiverAddress;
    }

    function setFeeReceiverAddress(address _address) public onlyOwner {
        feeReceiverAddress = _address;
        emit FeeReceiverAddressUpdated(_address);
    }

    function setCreateFee(uint256 _fee) public onlyOwner {
        createFee = _fee;
        emit CreateFeeUpdated(_fee);
    }

    function setBuyFee(uint256 _percent) public onlyOwner {
        buyFeePercent = _percent;
        emit BuyFeeUpdated(_percent);
    }

    function _addItem(
        uint256 _id,
        string memory _name,
        address _token,
        uint256 _price,
        address _owner
    ) private {
        require(items[_id].owner == address(0), "Item ID already exists");
        require(_price > 0, "Price must be greater than 0");

        itemCount++;
        items[_id] = Item({name: _name, owner: _owner, price: _price});
        itemPrice[_id][_token] = _price;
        ownerItems[_owner].push(_id);
    }

    function addMultipleItems(
        uint256[] memory _ids,
        string[] memory _names,
        address[] memory _tokens,
        uint256[] memory _prices,
        address[] memory _owners
    ) external onlyOwner {
        require(
            _ids.length == _names.length &&
            _ids.length == _tokens.length &&
            _ids.length == _prices.length &&
            _ids.length == _owners.length,
            "Invalid input lengths"
        );

        for (uint256 i = 0; i < _names.length; i++) {
            _addItem(_ids[i], _names[i], _tokens[i], _prices[i], _owners[i]);
        }
    }

    function addMultipleItemBuyers(
        uint256[] memory _ids,
        address[] memory _buyers
    ) external onlyOwner {
        require(_ids.length == _buyers.length, "Invalid input lengths");

        for (uint256 i = 0; i < _ids.length; i++) {
            purchaseItems[_buyers[i]].push(_ids[i]);
            isBoughtBy[_ids[i]][_buyers[i]] = true;
        }
    }

    function addItemOnPinky(
        uint256 _id,
        string memory _name,
        address _token,
        uint256 _price
    ) external payable nonReentrant {
        if (createFee > 0) {
            require(msg.value >= createFee, "Not enough funds");
            payable(feeReceiverAddress).transfer(createFee);
        }

        _addItem(_id, _name, _token, _price, msg.sender);

        emit ItemCreated(_id, msg.sender, _name, _token, _price);
    }

    function updateItemPrice(
        uint256 _id,
        address _token,
        uint256 _price
    ) external {
        Item storage item = items[_id];
        require(item.owner != address(0), "Invalid Item ID");
        require(item.owner == msg.sender, "You are not the owner");

        itemPrice[_id][_token] = _price;

        emit ItemPriceUpdated(_id, _token, _price);
    }

    function setItemDiscount(
        uint256 _id,
        uint256 _percent,
        uint256 _expiration
    ) public {
        Item storage item = items[_id];
        require(item.owner != address(0), "Invalid Item ID");
        require(item.owner == msg.sender, "You are not the owner");

        itemDiscounts[_id] = ItemDiscount({
            percent: _percent,
            expiration: _expiration
        });

        emit ItemDiscountSet(_id, _percent, _expiration);
    }

    function buyDappOnPinky(uint256 _id, address _token) external payable nonReentrant {
        Item storage item = items[_id];
        require(item.owner != address(0), "Invalid Item ID");

        uint256 price = itemPrice[_id][_token];
        require(item.owner != msg.sender, "You can't buy your own item");
        require(price > 0, "Unsupported token");

        // Apply discount
        if (itemDiscounts[_id].expiration > block.timestamp) {
            uint256 discount = (price * itemDiscounts[_id].percent) / 10000;
            price = price - discount;
        }

        uint256 fee = (price * buyFeePercent) / 10000;

        if (_token != address(0)) {
            IERC20(_token).safeTransferFrom(msg.sender, feeReceiverAddress, fee);
            IERC20(_token).safeTransferFrom(msg.sender, item.owner, price - fee);
        } else {
            require(msg.value >= price, "Not enough funds");
            payable(feeReceiverAddress).transfer(fee);
            payable(item.owner).transfer(msg.value - fee);
        }

        purchaseItems[msg.sender].push(_id);
        isBoughtBy[_id][msg.sender] = true;

        emit ItemPurchased(_id, item.owner, msg.sender, _token, price);
    }

    // Withdraw stuck ETH
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool sent, ) = payable(owner()).call{value: balance}("");
        if (!sent) revert TransferFailed(owner(), balance);
    }

    // Withdraw stuck tokens
    function withdrawToken(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        bool success = token.transfer(owner(), balance);
        if (!success) revert TransferFailed(owner(), balance);
    }

    // Fallbacks to accept ETH
    receive() external payable {}
    fallback() external payable {}
}
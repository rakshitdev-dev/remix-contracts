// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

/**
 * @title RentToken
 * @notice ERC20 token with snapshot capability (OZ v4.x)
 */
contract RentToken is ERC20, ERC20Snapshot, Ownable {
    address public snapshotter;

    constructor() ERC20("RentToken", "RENT") {
        _mint(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 1 ether);
        _mint(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 2 ether);
        _mint(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 3 ether);
        _mint(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 4 ether);
        _mint(0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 5 ether);
        _mint(0x17F6AD8Ef982297579C203069C1DbfFE4348c372, 6 ether);
        _mint(0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678, 7 ether);
    }

    function setSnapshotter(address _snapshotter) external onlyOwner {
        snapshotter = _snapshotter;
    }

    function snapshot() external returns (uint256) {
        require(msg.sender == snapshotter, "Not authorized");
        return _snapshot();
    }

    /// Required override
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }
}

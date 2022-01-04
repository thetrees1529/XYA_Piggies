// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "luk1529_solidity/contracts/fee/FeeTakersERC20.sol";

contract Items is Context, Ownable, ERC1155, ReentrancyGuard, FeeTakersERC20 {

    IERC20 _coinkx;

    struct Item {
        uint tokenId;
        uint price;
        uint stock;
    }

    Item[] _items;

    constructor(string memory uri, IERC20 coinkx) ERC1155("Piggie Items") FeeTakersERC20(coinkx) {
        _setURI(uri);
        _coinkx = coinkx;
    }

    function setURI(string memory uri) public onlyOwner {
        _setURI(uri);
    }

    function listingByIndex(uint index) public view returns(Item memory) {
        return _items[index];
    }

    function list(uint tokenId, uint price, uint stock) public onlyOwner {
        _items.push(Item(
            tokenId,
            price,
            stock
        ));
    }

    function buy(uint index, uint amount) public nonReentrant {
        Item storage item = _items[index];
        uint toPay = item.price * amount;
        _coinkx.transferFrom(msg.sender, address(this), toPay);
        _distributeFee(toPay);
        _mint(msg.sender, item.tokenId, amount, "");
        item.stock -= amount;
    }

    function removeListing(uint index) public onlyOwner {
        _items[index] = _items[_items.length - 1];
        _items.pop();
    }

    function withdrawCoinkx(uint amount) public onlyOwner {
        _coinkx.transfer(msg.sender, amount);
    }
}
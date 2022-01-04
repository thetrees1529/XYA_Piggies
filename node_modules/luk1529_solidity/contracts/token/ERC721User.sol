//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721User is Context, Ownable {
    IERC721 _ERC721Token;

    constructor(IERC721 Token) {
        _setERC721Token(Token);
    }

    function _setERC721Token(IERC721 ERC721Token) internal {
        _ERC721Token = ERC721Token;
    }

    function _getERC721Token() internal view returns(IERC721) {
        return _ERC721Token;
    }
}
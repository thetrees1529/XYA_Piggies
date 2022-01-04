//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721EnumerableUser is Context, Ownable {
    IERC721Enumerable _ERC721Token;

    constructor(IERC721Enumerable Token) {
        _setERC721Token(Token);
    }

    function _setERC721Token(IERC721Enumerable ERC721Token) internal {
        _ERC721Token = ERC721Token;
    }

    function _getERC721Token() internal view returns(IERC721Enumerable) {
        return _ERC721Token;
    }
}
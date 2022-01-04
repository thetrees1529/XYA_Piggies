//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20User is Context, Ownable {
    IERC20 _ERC20Token;

    constructor(IERC20 ERC20Token) {
        _setERC20Token(ERC20Token);
    }

    function _setERC20Token(IERC20 ERC20Token) internal {
        _ERC20Token = ERC20Token;
    }

    function _getERC20Token() internal view returns(IERC20) {
        return _ERC20Token;
    }
}
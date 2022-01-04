//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract Random {
  uint nonce;
  bytes salt;
  constructor(bytes memory _salt) {
      salt = _salt;
  }
  function _randomNumber(uint _upTo) internal returns(uint number) {
      uint res = uint(sha256(abi.encodePacked(nonce,  _getSalt())));
      number = res % _upTo;
      nonce ++;
  }
  function _getSalt() internal view virtual returns(bytes memory) {
      return salt;
  }
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract FeeTakersERC20 is Ownable{
    IERC20 _token;

    constructor(IERC20 token) {
        _token = token;
    }

    struct FeeTaker {
        address addr;
        uint points;
    }
    FeeTaker[] _feeTakers;

    event FeeSent(address to, uint amount);    

    //manage where profit is sent to
    function getFeeTakersLength() public view onlyOwner returns(uint) {
        return _feeTakers.length;
    }
    function getFeeTakerAt(uint index) public view onlyOwner returns(FeeTaker memory) {
        return _feeTakers[index];
    }
    function addToFeeTakers(address addr, uint points) public onlyOwner {
        _feeTakers.push(FeeTaker(addr, points));
    }
    function removeFromFeeTakers(uint index) public onlyOwner {
        _feeTakers[index] = _feeTakers[_feeTakers.length - 1];
        _feeTakers.pop();
    }

    function _distributeFee(uint fee) internal {
        uint feePoints;
        uint feePerPoint;
        for(uint i; i < _feeTakers.length; i ++) {
            feePoints += _feeTakers[i].points;
        }
        if(feePoints > 0) {
            feePerPoint = fee / feePoints;
        }
        for(uint i; i < getFeeTakersLength(); i ++) {
            FeeTaker storage feeTaker = _feeTakers[i];
            address feeTakerAddr = feeTaker.addr;
            uint toSend = feeTaker.points * feePerPoint;
            _token.transfer(feeTakerAddr, toSend);
            emit FeeSent(feeTakerAddr, toSend);
        }
    }
}
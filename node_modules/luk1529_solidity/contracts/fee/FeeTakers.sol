//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeTakers is Ownable {

    struct FeeTaker {
        address addr;
        uint points;
    }
    FeeTaker[] _feeTakers;

    event FeeSent(address to, uint amount);    

    //manage where profit is sent to

    function getFeeTakers() public view returns(FeeTaker[] memory) {
        return _feeTakers;
    }
    function addToFeeTakers(address addr, uint points) public onlyOwner {
        _feeTakers.push(FeeTaker(addr, points));
    }
    function removeFromFeeTakers(uint index) public onlyOwner {
        _feeTakers[index] = _feeTakers[_feeTakers.length - 1];
        _feeTakers.pop();
    }
    function deleteFeeTakers() public onlyOwner {
        delete _feeTakers;
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
        for(uint i; i < _feeTakers.length; i ++) {
            FeeTaker storage feeTaker = _feeTakers[i];
            address feeTakerAddr = feeTaker.addr;
            uint toSend = feeTaker.points * feePerPoint;
            feeTakerAddr.call{value: toSend}("");
            emit FeeSent(feeTakerAddr, toSend);
        }
    }
}
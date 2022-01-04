// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AttributeManagerV2 is Context, Ownable {
    event BoostAdded(uint indexed pigId, Boost);
    event NameSet(uint indexed pigId, string name);
    event DecaySet(uint indexed pigId, string attributeName, int effectPerSecond);
    event AttributeReset(uint indexed pigId, string attributeName);
    

    struct Boost {
        string name;
        int effect;
        uint startedAt;
        uint endsAt;
    }
    struct Decay {
        int effectPerSecond;
        uint startedAt;
    }
    struct Attribute {
        Boost[] boosts;
        Decay decay;
        int debt;
    }
    struct Pig {
        string name;
        mapping(string => Attribute) attributes;
    }
    struct Threshold {
        string attributeName;
        bool greaterThan;
        int value;
    }
    mapping(uint => Pig) _pigs;

    mapping(address => bool) _approvedToEdit;

    Threshold[] _limits;

    bool _enforceLock;

    //get name of a pig
    function getNameOfPig(uint pigId) public view returns(string memory) {
        return _pigs[pigId].name;
    }

    function getValueOfAttributeOfPig(uint pigId, string memory attributeName) public view returns(int value) {
        value = _getRawValueOfAttributeOfPig(pigId, attributeName);
        for(uint i; i < _limits.length; i ++) {
            if(keccak256(bytes(attributeName)) == keccak256(bytes(_limits[i].attributeName))) {
                if(_surpassesThreshold(pigId, _limits[i])) {
                    int difference = value - _limits[i].value;
                    value -= difference;
                }
            }
        }
    }

    function getActiveBoostsOfAttributeOfPig(uint pigId, string memory attributeName) public view returns(Boost[] memory boosts) {
        Attribute storage attribute = _pigs[pigId].attributes[attributeName];
        uint[] memory indexes = new uint[](attribute.boosts.length);
        uint pointer;
        for(uint i; i < attribute.boosts.length; i ++) {
            if(!_isBoostOver(attribute.boosts[i])) {
                indexes[pointer] = i;
                pointer ++;
            }
        }
        boosts = new Boost[](pointer);
        for(uint i; i < pointer; i ++) {
            boosts[i] = attribute.boosts[indexes[i]];
        }
    }

    function getDecayOfAttributeOfPig(uint pigId, string memory attributeName) public view returns(Decay memory decay) {
        Attribute storage attribute = _pigs[pigId].attributes[attributeName];
        return attribute.decay;
    }

    function addBoostToAttributeOfPig(uint pigId, string memory attributeName, string memory name, int effect, uint length) public onlyApprovedToEdit {
        for(uint i; i < _limits.length; i ++) {
            if(keccak256(bytes(attributeName)) == keccak256(bytes(_limits[i].attributeName))) {
                int value = _getRawValueOfAttributeOfPig(pigId, attributeName);
                if(_surpassesThreshold(pigId, _limits[i])) {
                    int difference = value - _limits[i].value;
                    _pigs[pigId].attributes[attributeName].debt -= difference;
                }
            }
        }
        Attribute storage attribute = _pigs[pigId].attributes[attributeName];
        Boost memory boost = Boost(name, effect, block.timestamp, block.timestamp + length);
        _tidyBoosts(attribute);
        if (!(length > 0)) {
            attribute.debt += effect;
        } else {
            attribute.boosts.push(boost);
        }
        for(uint i; i < _limits.length; i ++) {
            if(keccak256(bytes(attributeName)) == keccak256(bytes(_limits[i].attributeName))) {
                int value = _getRawValueOfAttributeOfPig(pigId, attributeName);
                if(_surpassesThreshold(pigId, _limits[i])) {
                    int difference = value - _limits[i].value;
                    _pigs[pigId].attributes[attributeName].debt -= difference;
                }
            }
        }
        emit BoostAdded(pigId, boost);
    }

    function setDecayOfAttributeOfPig(uint pigId, string memory attributeName, int effectPerSecond) public onlyApprovedToEdit {
        Attribute storage attribute = _pigs[pigId].attributes[attributeName];
        _clearDecay(attribute);
        attribute.decay = Decay(effectPerSecond, block.timestamp);
        for(uint i; i < _limits.length; i ++) {
            if(keccak256(bytes(attributeName)) == keccak256(bytes(_limits[i].attributeName))) {
                int value = _getRawValueOfAttributeOfPig(pigId, attributeName);
                if(_surpassesThreshold(pigId, _limits[i])) {
                    int difference = value - _limits[i].value;
                    _pigs[pigId].attributes[attributeName].debt -= difference;
                }
            }
        }
        emit DecaySet(pigId, attributeName, effectPerSecond);
    }

    function setNameOfPig(uint pigId, string memory name) public onlyApprovedToEdit {
        _pigs[pigId].name = name;
    }

    function resetAttributeOfPig(uint pigId, string memory attributeName) public onlyApprovedToEdit {
        delete _pigs[pigId].attributes[attributeName];
        emit AttributeReset(pigId, attributeName);
    }


    function setAttributeLimits(Threshold[] memory limits) public onlyApprovedToEdit {
        if(_limits.length > 0) {
            delete _limits;
        }

        for(uint i; i < limits.length; i ++) {
            _limits.push(limits[i]);
        }
    }

    function getAttributeLimits() public view returns(Threshold[] memory) {
        return _limits;
    }

  

    
    

    function _surpassesThreshold(uint pigId, Threshold storage threshold) private view returns(bool) {
        int value = _getRawValueOfAttributeOfPig(pigId, threshold.attributeName);
        bool greaterThan = value > threshold.value;
        return greaterThan == threshold.greaterThan;
    }
   


    function _tidyBoosts(Attribute storage attribute) private {
        uint i;
        while(i < attribute.boosts.length) {
            if(_isBoostOver(attribute.boosts[i])) {
                attribute.debt += _getEffectOfBoost(attribute.boosts[i]);
                attribute.boosts[i] = attribute.boosts[attribute.boosts.length - 1];
                attribute.boosts.pop();
            } else {
                i ++;
            }
        }
    }



    function _clearDecay(Attribute storage attribute) private {
        int effect = _getEffectOfDecay(attribute.decay);
        attribute.debt += effect;
        delete attribute.decay;
    }

    function _isBoostOver(Boost storage boost) private view returns(bool) {
        return block.timestamp >= boost.endsAt;
    }

    function _getEffectOfBoost(Boost storage boost) private view returns(int) {
        uint totalTime = boost.endsAt - boost.startedAt;
        uint timeSince = block.timestamp - boost.startedAt;
        uint effectiveTime = timeSince <= totalTime ? timeSince : totalTime;
        return (int(effectiveTime) * boost.effect) / int(totalTime);
    }
    function _getEffectOfDecay(Decay storage decay) private view returns(int) {
        uint effectiveTime = block.timestamp - decay.startedAt;
        return int(effectiveTime) * decay.effectPerSecond;
    }

    function _getRawValueOfAttributeOfPig(uint pigId, string memory attributeName) private view returns(int value) {
        Attribute storage attribute = _pigs[pigId].attributes[attributeName];
        for(uint i; i < attribute.boosts.length; i ++) {
            value += _getEffectOfBoost(attribute.boosts[i]);
        }
        value += _getEffectOfDecay(attribute.decay);
        value += attribute.debt;
    }



    function approveAddressToEdit(address addr, bool approval) public onlyOwner {
        _approvedToEdit[addr] = approval;
    }

    function isApprovedToEdit(address addr) public view returns(bool) {
        return _approvedToEdit[addr];
    }

    modifier onlyApprovedToEdit() {
        require(_approvedToEdit[msg.sender]);
        _;
    }


    


    

}
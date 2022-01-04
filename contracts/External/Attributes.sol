// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Attributes is Context, Ownable {

    struct Data {
        string[] rangeOfValues;
        mapping(string => bool) exists;
        mapping(uint => string) values;
    }

    string[] _rangeOfAttributes;
    mapping(string => bool) _exists;
    mapping(string => Data) _attributes;

    function setValueForAttributeOfPig(uint pigId, string calldata attributeName, string calldata value) public onlyOwner {
        _attributes[attributeName].values[pigId] = value;
        if(!_exists[attributeName]) {
            _rangeOfAttributes.push(attributeName);
            _exists[attributeName] = true;
        }
        if(!_attributes[attributeName].exists[value]) {
            _attributes[attributeName].rangeOfValues.push(value);
            _attributes[attributeName].exists[value] = true;
        }
    }

    function getValueForPigOfAttribute(uint pigId, string calldata attributeName) public view returns(string memory) {
        return _attributes[attributeName].values[pigId];
    }

    function getAllAttributes() public view returns(string[] memory) {
        return _rangeOfAttributes;
    }

    function getAllValuesForAttribute(string calldata attributeName) public view returns(string[] memory) {
        return _attributes[attributeName].rangeOfValues;
    }

    function bulkSetValueForAttributeOfPig(uint[] calldata pigIds, string[] calldata attributeNames, string[] calldata values) public onlyOwner {
        uint length = pigIds.length;
        for(uint i; i < length; i ++) {
            setValueForAttributeOfPig(pigIds[i], attributeNames[i], values[i]);
        }
    }
}
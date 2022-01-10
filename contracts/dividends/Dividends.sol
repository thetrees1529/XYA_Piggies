// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "luk1529_solidity/contracts/access/Admin.sol";
import "luk1529_solidity/contracts/token/ERC721EnumerableUser.sol";
import "luk1529_solidity/contracts/token/ERC20User.sol";
import "../attributes/AttributeManagerV2.sol";
import "../game/TamagotchiV2.sol";
import "../external/Attributes.sol";
import "../libraries/Math.sol";

contract Dividends is Context, Ownable, Admin, ERC721EnumerableUser, ERC20User {
    using Math for uint;
    event Claimed(address indexed player, uint indexed pigId, uint value);
    constructor(IERC721Enumerable piggies, IERC20 coink, AttributeManagerV2 attributeManager, TamagotchiV2 tamagotchi, Attributes attributes, uint epochLength) ERC20User(coink) ERC721EnumerableUser(piggies) {
        _epochLength = epochLength;
        _attributes = attributes;
        _attributeManager = attributeManager;
        _tamagotchi = tamagotchi;
        _birth = block.timestamp;
    }

    struct Multiplier {
        string name;
        string value;

        uint multiplier;
    }

    struct PigData {
        bool void;
        bool registered;
        bool claimed;
        uint allocPoints;
    }

    struct Epoch {
        bool ended;
        uint distributed;
        uint claimed;
        uint totalAllocPoints;
        mapping(uint => PigData) pigs;
    }
    struct BigDaddyResult {
        uint registered;
        uint claimed;
        BigDaddyPigResult[] bigDaddyPigResults;
    }
    struct BigDaddyPigResult {
        uint pigId;
        bool registered;
        bool claimed;

        uint claimable;
        uint claimableNextEpoch;


        int attributeValue;
        uint multiplier;
    }

    uint _birth;

    string _attributeToTrack;
    AttributeManagerV2 _attributeManager;
    TamagotchiV2 _tamagotchi;
    Attributes _attributes;
    Multiplier[] _multipliers;
    uint _percentPerEpoch;

    uint _epochLength;

    mapping(uint => Epoch) _epochs;

    function currentEpochNumber() public view returns(uint) {
        uint timeSinceBirth = block.timestamp - _birth;
        return timeSinceBirth / _epochLength + 1;
    }

    function lastEpochEnded() public view returns(bool) {
        uint epochNumber = currentEpochNumber() - 1;
        Epoch storage epoch = _epochs[epochNumber];

        return epoch.ended;
    }

    function registered(uint pigId) public view returns(bool) {
        uint epochNumber = currentEpochNumber();
        Epoch storage epoch = _epochs[epochNumber];

        return epoch.pigs[pigId].registered;
    }

    function claimed(uint pigId) public view returns(bool) {
        uint epochNumber = currentEpochNumber() - 1;
        Epoch storage epoch = _epochs[epochNumber];

        return epoch.pigs[pigId].claimed;
    }

    function claimable(uint pigId) public view returns(uint) {
        uint epochNumber = currentEpochNumber() - 1;
        Epoch storage epoch = _epochs[epochNumber];

        if(!epoch.pigs[pigId].registered || epoch.pigs[pigId].claimed || epoch.pigs[pigId].allocPoints == 0) {
            return 0;
        }
        if(!epoch.ended) {
            uint balance = _coinkContract().balanceOf(address(this));
            uint toDistribute = (balance * _percentPerEpoch) / 1e2;
            return (toDistribute * epoch.pigs[pigId].allocPoints) / epoch.totalAllocPoints;
        }
        return (epoch.distributed * epoch.pigs[pigId].allocPoints) / epoch.totalAllocPoints;
    }

    function claimableNextEpoch(uint pigId) public view returns(uint) {
        uint epochNumber = currentEpochNumber();
        Epoch storage epoch = _epochs[epochNumber];
        Epoch storage lastEpoch = _epochs[epochNumber - 1];

        if(!lastEpoch.ended) {
            return 0;
        }

        uint balance = _coinkContract().balanceOf(address(this));

        uint pool = balance - (lastEpoch.distributed - lastEpoch.claimed);

        if(epoch.pigs[pigId].allocPoints == 0) {
            return 0;
        }
        return (epoch.pigs[pigId].allocPoints * pool * _percentPerEpoch) / (epoch.totalAllocPoints * 1e2);
    }

    function multiplier(uint pigId) public view returns(uint multiplier) {
        for(uint i; i < _multipliers.length; i ++) {
            string memory value = _attributesContract().getValueForPigOfAttribute(pigId, _multipliers[i].name);
            if(keccak256(bytes(value)) == keccak256(bytes(_multipliers[i].value))) {
                multiplier += _multipliers[i].multiplier;
            }
        }
    }

    function bigDaddyFunction(address player) public view returns(BigDaddyResult memory bigDaddyResult) {
        uint balance = _piggiesContract().balanceOf(player);
        bigDaddyResult.bigDaddyPigResults = new BigDaddyPigResult[](balance);
        for(uint i; i < balance; i ++) {
            uint pigId = _piggiesContract().tokenOfOwnerByIndex(player, i);
            bool claimed = claimed(pigId);
            bool registered = registered(pigId);
            uint claimable = claimable(pigId);
            uint claimableNextEpoch = claimableNextEpoch(pigId);
            int attributeValue = _attributeManagerContract().getValueOfAttributeOfPig(pigId, _attributeToTrack);
            uint multiplier = multiplier(pigId);

            bigDaddyResult.bigDaddyPigResults[i].pigId = pigId;
            bigDaddyResult.bigDaddyPigResults[i].claimed = claimed;
            bigDaddyResult.bigDaddyPigResults[i].registered = registered;
            bigDaddyResult.bigDaddyPigResults[i].claimable = claimable;
            bigDaddyResult.bigDaddyPigResults[i].claimableNextEpoch = claimableNextEpoch;
            bigDaddyResult.bigDaddyPigResults[i].attributeValue = attributeValue;
            bigDaddyResult.bigDaddyPigResults[i].multiplier = multiplier;

            if(claimed) {
                bigDaddyResult.claimed ++;
            }
            if(registered) {
                bigDaddyResult.registered ++;
            }
        }
    }

    function registerPig(uint pigId) public onlyOwnerOfPig(pigId) onlyAlivePig(pigId) {
        uint epochNumber = currentEpochNumber();
        Epoch storage epoch = _epochs[epochNumber];

        require(!epoch.pigs[pigId].void, "This pig is not allowed to register during this epoch.");

        if(!epoch.pigs[pigId].registered) {
            _accountForRegistering(pigId);
            epoch.pigs[pigId].registered = true;
        } else {
            epoch.totalAllocPoints -= epoch.pigs[pigId].allocPoints;
            epoch.pigs[pigId].allocPoints = 0;
            _accountForRegistering(pigId);
        }

    }

    function claim(uint pigId) public onlyOwnerOfPig(pigId) onlyAlivePig(pigId) {
        uint epochNumber = currentEpochNumber() - 1;
        Epoch storage epoch = _epochs[epochNumber];

        require(epoch.ended, "Please end the last epoch before claiming from it.");
        require(!epoch.pigs[pigId].claimed, "Cannot claim twice.");

        uint toClaim = claimable(pigId);

        _coinkContract().transfer(msg.sender, toClaim);

        epoch.pigs[pigId].claimed = true;
        epoch.claimed += toClaim;

        emit Claimed(msg.sender, pigId, toClaim);
    }

    function bulkRegisterPig(uint[] calldata pigIds) public {
        for(uint i; i < pigIds.length; i ++) {
            registerPig(pigIds[i]);
        }
    }

    function bulkClaimPig(uint[] calldata pigIds) public {
        for(uint i; i < pigIds.length; i ++) {
            claim(pigIds[i]);
        }
    }

    

    function endLastEpoch() public {
        uint epochNumber = currentEpochNumber() - 1;
        Epoch storage epoch = _epochs[epochNumber];

        require(!epoch.ended, "This epoch has already ended.");
        epoch.distributed = (_coinkContract().balanceOf(address(this)) * _percentPerEpoch) / 1e2;
        epoch.ended = true;
    }

    function getMultipliers() public view returns(Multiplier[] memory) {
        return _multipliers;
    }

    function voidPig(uint pigId) public onlyAdmin {
        uint epochNumber = currentEpochNumber() - 1;
        Epoch storage epoch = _epochs[epochNumber];
        PigData storage pig = epoch.pigs[pigId];
        if(!pig.void && pig.registered) {
            epoch.totalAllocPoints -= pig.allocPoints;
            pig.allocPoints -= pig.allocPoints;
            pig.void = true;
        }
    }

    function setMultipliers(Multiplier[] calldata multipliers) public onlyOwner {
        if(_multipliers.length > 0) {
            delete _multipliers;
        }

        for(uint i; i < multipliers.length; i ++) {
            _multipliers.push(multipliers[i]);
        }
    }
    function setAttributeToTrack(string calldata name) public onlyOwner {
        _attributeToTrack = name;
    }
    function setPercentPerEpoch(uint percentPerEpoch) public onlyOwner {
        _percentPerEpoch = percentPerEpoch;
    }
    function _attributeValueToAllocPoints(int value) private pure returns(uint) {
        if(value < 0) {
            return 0;
        }
        return uint(value).sqrt();
    }
    function _accountForRegistering(uint pigId) private {
        uint epochNumber = currentEpochNumber();
        Epoch storage epoch = _epochs[epochNumber];

        int value = _attributeManagerContract().getValueOfAttributeOfPig(pigId, _attributeToTrack);
        uint multiplier = multiplier(pigId);
        uint allocPoints = _attributeValueToAllocPoints(value);
        allocPoints *= multiplier;

        epoch.totalAllocPoints += allocPoints;
        epoch.pigs[pigId].allocPoints = allocPoints;
    }
    modifier onlyOwnerOfPig(uint pigId) {
        require(_piggiesContract().ownerOf(pigId) == msg.sender, "You are not the owner of this pig.");
        _;
    }
    modifier onlyAlivePig(uint pigId) {
        require(!_tamagotchiContract().isDead(pigId), "This pig is dead.");
        _;
    }

    function _coinkContract() private view returns(IERC20) {
        return _getERC20Token();
    }
    function _piggiesContract() private view returns(IERC721Enumerable) {
        return _getERC721Token();
    }
    function _attributesContract() private view returns(Attributes) {
        return _attributes;
    }
    function _attributeManagerContract() private view returns(AttributeManagerV2) {
        return _attributeManager;
    }
    function _tamagotchiContract() private view returns(TamagotchiV2) {
        return _tamagotchi;
    }

    function emergencyWithdraw(uint amount) public onlyOwner {
        _coinkContract().transfer(msg.sender, amount);
    }
}
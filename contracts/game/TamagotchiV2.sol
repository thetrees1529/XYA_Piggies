// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "luk1529_solidity/contracts/token/ERC721User.sol";
import "luk1529_solidity/contracts/fee/FeeTakersERC20.sol";
import "luk1529_solidity/contracts/utils/Random.sol";
import "../attributes/AttributeManagerV2.sol";

contract TamagotchiV2 is Ownable, FeeTakersERC20, Random("toomoogoochoo") {


    constructor(IERC721 piggies, IERC20 coinkx, AttributeManagerV2 attributeManager) FeeTakersERC20(coinkx) {
        _coinkx = coinkx;
        _piggies = piggies;
        _attributeManager = attributeManager;
    }

    IERC20 _coinkx;
    IERC721 _piggies;
    AttributeManagerV2 _attributeManager;

    struct BoostInitialiser {
        string attributeName;
        string name;
        int effect;
        uint length;
    }
    struct DecayInitialiser {
        string attributeName;
        int effectPerSecond;
    }
    struct AttributesInitialiser {
        BoostInitialiser[] boostInitialisers;
        DecayInitialiser[] decayInitialisers;
    }
    struct Powerup {
        string name;
        string[] cantBeOccupied;
        Occupy[] occupies;
        uint price;
        BoostInitialiser[] boostInitialisers;
        Threshold[] thresholds;
    }
    struct RandomEvent {
        string name;
        uint percentageChance;
        BoostInitialiser[] boostInitialisers;
        Threshold[] thresholds;
    }
    struct Threshold {
        string attributeName;
        bool greaterThan;
        int value;
    }
    struct Occupy {
        string name;
        uint length;
    }
    

    string[] _defaultAttributeList;
    string[] _defaultCooldownList;
    AttributesInitialiser _attributesInitialiser;
    Powerup[] _powerups;
    Threshold[] _deathThresholds;
    RandomEvent[] _randomEvents;
    uint _revivalPrice;

    mapping(uint => bool) _imported;
    mapping(uint => mapping(string => uint)) _occupiedUntil;
    mapping(uint => string[]) _eventHistory;

    function importPig(uint pigId) public onlyOwnerOfPig(pigId) {
        require(!isImported(pigId), "This pig has already been imported.");
        _resetPig(pigId);
        _imported[pigId] = true;
    }

    function revivePig(uint pigId) public onlyOwnerOfPig(pigId) {
        require(isImported(pigId), "This pig hasn't been imported yet.");
        require(isDead(pigId), "This pig isn't dead.");
        _receivePayment(msg.sender, _revivalPrice);
        _resetPig(pigId);
    }

    function canBuyPowerup(uint pigId, uint index) public view returns(bool canBuy, string[] memory occupied, string[] memory notSurpassedThresholds) {
        occupied = _getOccupied(pigId, _powerups[index].cantBeOccupied);
        notSurpassedThresholds = _getNotSurpassedThresholds(pigId, _powerups[index].thresholds);
        canBuy = !(occupied.length > 0) && !(notSurpassedThresholds.length > 0);
    }

    function buyPowerup(uint pigId, uint index) public onlyOwnerOfPig(pigId) onlyImportedPig(pigId) onlyNotDeadPig(pigId) applyRandomEventsAfter(pigId) {
        Powerup storage powerup = _powerups[index];
        uint toPay = powerup.price;
        require(!(_getOccupied(pigId, powerup.cantBeOccupied).length > 0), "This pig is too occupied for this task.");
        require(!(_getNotSurpassedThresholds(pigId, powerup.thresholds).length > 0), "This pig does not meet all the thresholds for using this powerup.");
        _receivePayment(msg.sender, toPay);
        _applyBoostsToPig(pigId, powerup.boostInitialisers);
        _occupyFor(pigId, powerup.occupies);
        _addToEventHistory(pigId, powerup.name);
    }

    function setNameOfPig(uint pigId, string calldata name) public onlyOwnerOfPig(pigId) {
        _attributeManagerContract().setNameOfPig(pigId, name);
    }

    function getPowerups() public view returns(Powerup[] memory) {
        return _powerups;
    }

    function getDefaultAttributeList() public view returns(string[] memory) {
        return _defaultAttributeList;
    }

    function isDead(uint pigId) public view returns(bool) {
        string[] memory doesntSurpassThreshold = _getNotSurpassedThresholds(pigId, _deathThresholds);
        return doesntSurpassThreshold.length != _deathThresholds.length;

    }

    function isImported(uint pigId) public view returns(bool) {
        return _imported[pigId];
    }
    function occupiedUntil(uint pigId, string memory occupy) public view returns(uint) {
        return _occupiedUntil[pigId][occupy];
    }
    function isOccupied(uint pigId, string memory occupy) public view returns(bool) {
        return block.timestamp < occupiedUntil(pigId, occupy);
    }

    function getEventHistoryOfPig(uint pigId, uint howMany, uint skip) public view returns(string[] memory events) {
        uint endsAt = _eventHistory[pigId].length - skip;
        uint index = endsAt - howMany;
        events = new string[](endsAt - index);
        for(uint i = index; i < endsAt; i ++) {
            events[i - index] = events[i];
        }
    }




    function setDefaultAttributeList(string[] memory defaultAttributeList) public onlyOwner {
        _defaultAttributeList = defaultAttributeList;
    }
    function setDefaultCooldownList(string[] memory defaultCooldownList) public onlyOwner {
        _defaultCooldownList = defaultCooldownList;
    }
    function setAttributesInitialiser(AttributesInitialiser memory attributesInitialiser) public onlyOwner {
        if(_attributesInitialiser.boostInitialisers.length > 0) {
            delete _attributesInitialiser.boostInitialisers;
        }
        if(_attributesInitialiser.decayInitialisers.length > 0) {
            delete _attributesInitialiser.decayInitialisers;
        }
        for(uint i; i < attributesInitialiser.boostInitialisers.length; i ++) {
            _attributesInitialiser.boostInitialisers.push(attributesInitialiser.boostInitialisers[i]);
        }
        for(uint i; i < attributesInitialiser.decayInitialisers.length; i ++) {
            _attributesInitialiser.decayInitialisers.push(attributesInitialiser.decayInitialisers[i]);
        }
    }
    function setPowerups(Powerup[] memory powerups) public onlyOwner {
        if(_powerups.length > 0) {
            delete _powerups;
        }

        for(uint i; i < powerups.length; i ++) {
            _powerups.push();
            _powerups[i].name = powerups[i].name;
            _powerups[i].price = powerups[i].price; 
            _powerups[i].cantBeOccupied = powerups[i].cantBeOccupied;

            for(uint j; j < powerups[i].occupies.length; j ++) {
                _powerups[i].occupies.push(powerups[i].occupies[j]);
            }
            for(uint j; j < powerups[i].boostInitialisers.length; j ++) {
                _powerups[i].boostInitialisers.push(powerups[i].boostInitialisers[j]);
            }
            for(uint j; j < powerups[i].thresholds.length; j ++) {
                _powerups[i].thresholds.push(powerups[i].thresholds[j]);
            }
        }
    }
    function setDeathThresholds(Threshold[] memory deathThresholds) public onlyOwner {
        if(_deathThresholds.length > 0) {
            delete _deathThresholds;
        }

        for(uint i; i < deathThresholds.length; i ++) {
            _deathThresholds.push(deathThresholds[i]);
        }
    }

    function setRandomEvents(RandomEvent[] memory randomEvents) public onlyOwner {
        if(_randomEvents.length > 0) {
            delete _randomEvents;
        }
        for(uint i; i < randomEvents.length; i ++) {
            _randomEvents.push();
            _randomEvents[i].name = randomEvents[i].name;
            _randomEvents[i].percentageChance = randomEvents[i].percentageChance;
            for(uint j; j < _randomEvents[i].boostInitialisers.length; j ++) {
                _randomEvents[i].boostInitialisers.push(randomEvents[i].boostInitialisers[j]);
            }
            for(uint j; j < _randomEvents[i].thresholds.length; j ++) {
                _randomEvents[i].thresholds.push(randomEvents[i].thresholds[j]);
            }
        }
    }
    function setRevivalPrice(uint revivalPrice) public onlyOwner {
        _revivalPrice = revivalPrice;
    }
    function _getOccupied(uint pigId, string[] storage occupies) private view returns(string[] memory occupied) {
        uint[] memory indexes = new uint[](occupies.length);
        uint pointer;
        for(uint i; i < occupies.length; i ++) {
            if(isOccupied(pigId, occupies[i])) {
                indexes[pointer] = i;
                pointer ++;
            }
        }
        occupied = new string[](pointer);
        for(uint i; i < pointer; i ++) {
            occupied[i] = occupies[indexes[i]];
        }
    }
    
    function _getNotSurpassedThresholds(uint pigId, Threshold[] storage thresholds) private view returns(string[] memory passedThreshold) {
        uint[] memory indexes = new uint[](thresholds.length);
        uint pointer;
        for(uint i; i < thresholds.length; i ++) {
            if(!_surpassesThreshold(pigId, thresholds[i])) {
                indexes[pointer] = i;
                pointer ++;
            }
        }
        passedThreshold = new string[](pointer);
        for(uint i; i < pointer; i ++) {
            passedThreshold[i] = thresholds[indexes[i]].attributeName;
        }
    }
    function _surpassesThreshold(uint pigId, Threshold storage threshold) private view returns(bool) {
        int value = _attributeManagerContract().getValueOfAttributeOfPig(pigId, threshold.attributeName);
        bool greaterThan = value > threshold.value;
        return greaterThan == threshold.greaterThan;
    }

    function _resetPig(uint pigId) private {
        for(uint i; i < _defaultAttributeList.length; i ++) {
            _attributeManagerContract().resetAttributeOfPig(pigId, _defaultAttributeList[i]);
        }
        for(uint i; i < _attributesInitialiser.boostInitialisers.length; i ++) {
            _attributeManagerContract().addBoostToAttributeOfPig(
                pigId,
                _attributesInitialiser.boostInitialisers[i].attributeName,
                _attributesInitialiser.boostInitialisers[i].name,
                _attributesInitialiser.boostInitialisers[i].effect,
                _attributesInitialiser.boostInitialisers[i].length
            );
        }
        for(uint i; i < _attributesInitialiser.decayInitialisers.length; i ++) {
            _attributeManagerContract().setDecayOfAttributeOfPig(
                pigId,
                _attributesInitialiser.decayInitialisers[i].attributeName,
                _attributesInitialiser.decayInitialisers[i].effectPerSecond
            );
        }
        for(uint i; i < _defaultCooldownList.length; i ++) {
            delete _occupiedUntil[pigId][_defaultCooldownList[i]];
        }
    }
    function _addToEventHistory(uint pigId, string storage eventToAdd) private {
        _eventHistory[pigId].push(eventToAdd);
    }
    function _applyBoostsToPig(uint pigId, BoostInitialiser[] storage boostInitialisers) private {
        for(uint i; i < boostInitialisers.length; i ++) {
            _attributeManagerContract().addBoostToAttributeOfPig(pigId, boostInitialisers[i].attributeName, boostInitialisers[i].name, boostInitialisers[i].effect, boostInitialisers[i].length);
        }
    }
    function _applyDecayToPig(uint pigId, string storage attributeName, int effectPerSecond) private {
        _attributeManagerContract().setDecayOfAttributeOfPig(pigId, attributeName, effectPerSecond);
    }

    function _occupyFor(uint pigId, Occupy[] storage occupies) private {
        for(uint i; i < occupies.length; i ++) {
             _occupiedUntil[pigId][occupies[i].name] = block.timestamp + occupies[i].length;
        }
    }
    modifier onlyOwnerOfPig(uint pigId) {
        require(_piggiesContract().ownerOf(pigId) == msg.sender, "Only the owner of this pig may do this action.");
        _;
    }
    modifier onlyImportedPig(uint pigId) {
        require(isImported(pigId), "Only imported pigs may do this action.");
        _;
    }
    modifier onlyNotDeadPig(uint pigId) {
        require(!isDead(pigId),
        "Unfortunately, your pig is dead.");
        _;
    }
    modifier applyRandomEventsAfter(uint pigId) {
        _;
        for(uint i; i < _randomEvents.length; i ++) {
            if(_getNotSurpassedThresholds(pigId, _randomEvents[i].thresholds).length == 0) {
                bool toApply = _randomNumber(100) < _randomEvents[i].percentageChance;
                if(toApply) {
                    _applyBoostsToPig(pigId, _randomEvents[i].boostInitialisers);
                    _addToEventHistory(pigId, _randomEvents[i].name);
                }
            }
        }
    }

    function _receivePayment(address from, uint amount) private {
        _coinkContract().transferFrom(from, address(this), amount);
        _distributeFee(amount);
    }

    function _attributeManagerContract() private view returns(AttributeManagerV2) {
        return _attributeManager;
    }
    function _piggiesContract() private view returns(IERC721) {
        return _piggies;
    }
    function _coinkContract() private view returns(IERC20) {
        return _coinkx;
    }

    function withdraw(uint amount) public onlyOwner {
        _coinkContract().transfer(msg.sender, amount);
    }

}
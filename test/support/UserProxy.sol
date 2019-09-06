pragma solidity ^0.5.8;

import "../../contracts/ERC1404.sol";
contract UserProxy {
    ERC1404 public token;
    
    constructor(ERC1404 _token) public {
        token = _token;
    }

    function transfer(address to, uint amount) public returns(bool success) {
        return token.transfer(to, amount);
    }

    function setMaxBalance(address _account, uint256 _updatedValue) public {
        token.setMaxBalance(_account, _updatedValue);
    }
}
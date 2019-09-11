pragma solidity ^0.5.8;

import "../../contracts/RestrictedToken.sol";
contract UserProxy {
    RestrictedToken public token;
    
    constructor(RestrictedToken _token) public {
        token = _token;
    }

    function transfer(address to, uint amount) public returns(bool success) {
        return token.transfer(to, amount);
    }

    function setMaxBalance(address _account, uint256 _updatedValue) public {
        token.setMaxBalance(_account, _updatedValue);
    }
}
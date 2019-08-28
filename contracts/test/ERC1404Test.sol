pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";

contract ERC1404Test {
    ERC1404 token;

    function beforeEach() public {
        token = new ERC1404("xyz");
    }

    function testSymbolName() public {
        string memory symbol = 'xyz';
        Assert.equal(token.symbol(), symbol, "should return the token symbol");
    }    
}
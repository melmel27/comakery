pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/ERC1404.sol";

contract MintBurnTest {
    ERC1404 public token;
    UserProxy public alice;
    
    function beforeEach() public {
        token = new ERC1404(address(this), "xyz", "Ex Why Zee", 6, 1234567);
        alice = new UserProxy(token);
    }

    function testMint() public {
        Assert.equal(token.symbol(), "xyz", "wut?");
    }
}
pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/ERC1404.sol";

contract MintBurnTest {
    ERC1404 public token;
    UserProxy public alice;

    function beforeEach() public {
        token = new ERC1404(address(this), "xyz", "Ex Why Zee", 0, 100);        
        alice = new UserProxy(token);
    }

    function testBurn() public {
        Assert.equal(token.balanceOf(address(this)), 100, "wrong balance for owner");
        token.transfer(address(alice), 17);
        
        Assert.equal(token.totalSupply(), 100, "incorrect total supply");
        Assert.equal(token.balanceOf(address(alice)), 17, "wrong balance for alice");
        
        token.burnFrom(address(alice), 17);
        Assert.equal(token.balanceOf(address(alice)), 0, "wrong balance for alice");
        Assert.equal(token.totalSupply(), 83, "incorrect total supply");
    }
}
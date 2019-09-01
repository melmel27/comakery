pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/ERC1404.sol";

contract MintBurnFreezeTest {
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

    function testCannotBurnMoreThanAddressBalance() public {
        token.transfer(address(alice), 10);
        (bool success,) = address(token).call(abi.encodeWithSignature("burnFrom(address,uint256)", address(alice), 11));
        Assert.isFalse(success, "should fail to burn if address does not have enough balance to burn");

        Assert.equal(token.totalSupply(), 100, "incorrect total supply");
        Assert.equal(token.balanceOf(address(alice)), 10, "wrong balance for alice");
    }

    function testMint() public {
        Assert.equal(token.balanceOf(address(this)), 100, "wrong balance for owner");
        Assert.equal(token.balanceOf(address(alice)), 0, "wrong balance for owner");
        Assert.equal(token.totalSupply(), 100, "incorrect total supply");

        token.mint(address(alice), 10);

        Assert.equal(token.balanceOf(address(alice)), 10, "wrong balance for owner");
        Assert.equal(token.totalSupply(), 110, "incorrect total supply");
    }

    function testCannotMintMoreThanMaxUintValue() public {
        (bool success,) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", address(alice), token.MAX_UINT()));
        Assert.isFalse(success, "should fail because it exceeds the max uint256 value");
    }

    function testFreeze() public {
        UserProxy bob = new UserProxy(token);
        token.transfer(address(alice), 10);
        token.setApprovedReceiver(address(bob), 100);
        token.freeze(address(alice), true);
        
        uint8 code = token.detectTransferRestriction(address(alice), address(bob), 1);
        Assert.equal(uint256(code), 5, "wrong transfer restriction code for frozen account");

        Assert.equal(token.messageForTransferRestriction(code), "SENDER ADDRESS IS FROZEN", "wrong transfer restriction code for frozen account");
    }
}
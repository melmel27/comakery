pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/RestrictedToken.sol";

contract FreezeTest {
    RestrictedToken public token;
    address tokenContractOwner;
    address public alice;

    function beforeEach() public {
        alice = address(0x1);
        tokenContractOwner = address(this);
        token = new RestrictedToken(tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 100);
        token.grantTransferAdmin(tokenContractOwner);
        token.setMaxBalance(alice, 1000);
        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testFreeze() public {
        address bob = address(0x2);
        token.transfer(alice, 10);
        token.setMaxBalance(address(bob), 100);
        token.freeze(alice, true);
        
        uint8 code = token.detectTransferRestriction(alice, address(bob), 1);
        Assert.equal(uint256(code), 5, "wrong transfer restriction code for frozen account");

        Assert.equal(token.transferRules().messageForTransferRestriction(code), "SENDER ADDRESS IS FROZEN", "wrong transfer restriction code for frozen account");
    }

    function testCanPauseTransfers() public {
        Assert.isFalse(token.isPaused(), "should not be paused yet");
        token.pause();
        Assert.isTrue(token.isPaused(), "should be paused");
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), alice, 1);
        Assert.equal(uint(restrictionCode), 6, "should not be able to transfer when contract is paused");

        token.unpause();
        Assert.isFalse(token.isPaused(), "should be unpaused");
        restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), alice, 1);
        Assert.equal(uint(restrictionCode), 0, "should be able to transfer when contract is unpaused");
    }
}
pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/ERC1404.sol";

contract FreezeTest {
    ERC1404 public token;
    address tokenContractOwner;
    UserProxy public alice;

    function beforeEach() public {
        tokenContractOwner = address(this);
        token = new ERC1404(tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 100);
        alice = new UserProxy(token);
        token.setMaxBalance(address(alice), 1000);
        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testFreeze() public {
        UserProxy bob = new UserProxy(token);
        token.transfer(address(alice), 10);
        token.setMaxBalance(address(bob), 100);
        token.freeze(address(alice), true);
        
        uint8 code = token.detectTransferRestriction(address(alice), address(bob), 1);
        Assert.equal(uint256(code), 5, "wrong transfer restriction code for frozen account");

        Assert.equal(token.transferRules().messageForTransferRestriction(code), "SENDER ADDRESS IS FROZEN", "wrong transfer restriction code for frozen account");
    }

    function testCanPauseTransfers() public {
        Assert.isFalse(token.isPaused(), "should not be paused yet");
        token.pause();
        Assert.isTrue(token.isPaused(), "should be paused");
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(alice), 1);
        Assert.equal(uint(restrictionCode), 6, "should not be able to transfer when contract is paused");

        token.unpause();
        Assert.isFalse(token.isPaused(), "should be unpaused");
        restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(alice), 1);
        Assert.equal(uint(restrictionCode), 0, "should be able to transfer when contract is unpaused");
    }
}
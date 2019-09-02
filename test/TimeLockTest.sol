pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";
import "./support/UserProxy.sol";

contract TimeLockTest {
    ERC1404 token;
    address tokenContractOwner;
    UserProxy public alice;
    UserProxy public bob;
    UserProxy public chuck;

    function beforeEach() public {
        tokenContractOwner = address(this);
        token = new ERC1404(tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);

        alice = new UserProxy(token);
        bob = new UserProxy(token);
        chuck = new UserProxy(token);
    }

    function testAdminCanLockupTokensForASpecificTime() public {
        uint lockupTill = now + 10000;
        token.setTimeLock(address(alice), lockupTill);
        Assert.equal(token.getTimeLock(address(alice)), lockupTill, "not locked up as expected");

        token.setMaxBalance(address(bob), 17);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 2, "should have tokens locked");
    }
    
     function testAdminCanUnlockTokens() public {
        uint lockupTill = now + 10000;
        token.setTimeLock(address(alice), lockupTill);
        token.setMaxBalance(address(bob), 17);
        token.removeTimeLock(address(alice));

        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 0, "should not have tokens locked");
    }
}
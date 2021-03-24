pragma solidity 0.5.12;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/RestrictedToken.sol";
import "../../contracts/TransferRules.sol";
import "./support/UserProxy.sol";

contract TimeLockTest {
    RestrictedToken token;
    address tokenContractOwner;
    UserProxy public alice;
    UserProxy public bob;
    UserProxy public chuck;
    address reserveAdmin;

    function beforeEach() public {
        tokenContractOwner = address(this);
        reserveAdmin = address(0x1);
        TransferRules rules = new TransferRules();
        token = new RestrictedToken(address(rules), tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 0, 100, 1e6);
        token.grantTransferAdmin(tokenContractOwner);
        token.grantWalletsAdmin(tokenContractOwner);

        alice = new UserProxy(token);
        bob = new UserProxy(token);
        chuck = new UserProxy(token);

        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testAdminCanLockupTokensForASpecificTime() public {
        uint lockupTill = now + 10000;
        token.setLockUntil(address(alice), lockupTill);
        Assert.equal(token.getLockUntil(address(alice)), lockupTill, "not locked up as expected");

        token.setMaxBalance(address(bob), 17);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 2, "should have tokens locked");
    }
    
     function testAdminCanUnlockTokens() public {
        uint lockupTill = now + 10000;
        token.setLockUntil(address(alice), lockupTill);
        token.setMaxBalance(address(bob), 17);
        token.removeLockUntil(address(alice));

        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 0, "should not have tokens locked");
    }
}

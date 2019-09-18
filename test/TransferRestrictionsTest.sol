pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RestrictedToken.sol";
import "./support/UserProxy.sol";

contract TransferRestrictionsTest {
    RestrictedToken token;
    address tokenContractOwner;
    address alice;
    address bob;

    uint256 groupA = 1;
    uint256 groupB = 2;
    uint256 transferTimeIsNow = now;
    uint maxTokens = 1000;
    uint restrictionCode;

    function beforeEach() public {
        tokenContractOwner = address(this);
        token = new RestrictedToken(tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);
        token.grantTransferAdmin(tokenContractOwner);
        
        alice = address(0x1);
        bob = address(0x2);

        token.setAccountPermissions(alice, groupA, transferTimeIsNow, maxTokens, false);
        token.setAccountPermissions(bob, groupB, transferTimeIsNow, maxTokens, false);
    }

    function testTransferRestrictionsBetweenUsersNotOnWhitelist() public {
        restrictionCode = token.detectTransferRestriction(alice, bob, 17);
        Assert.equal(uint(restrictionCode), 7, "no transfers should work before transfer groups are approved");

        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow);
        restrictionCode = token.detectTransferRestriction(alice, bob, maxTokens + 1);
        Assert.equal(uint(restrictionCode), 1, "should fail if max balance would be exceeded in transfer");
   

        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow + 1 days);
        restrictionCode = token.detectTransferRestriction(alice, bob, 17);
        Assert.equal(uint(restrictionCode), 8, "approved transfers should not work before the specified time");
  
        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow);
        restrictionCode = token.detectTransferRestriction(alice, bob, 17);
        Assert.equal(uint(restrictionCode), 0, "approved transfers should work after the specified time");

        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow);
        restrictionCode = token.detectTransferRestriction(bob, alice, 17); // reversed transfer direction!
        Assert.equal(uint(restrictionCode), 7, "approved transfers should not work when transfer between groups is not approved");

        restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(token), 17);
        Assert.equal(uint(restrictionCode), 3, "should not be able to send tokens to the contract itself");

        restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(0), 17);
        Assert.equal(uint(restrictionCode), 4, "should not be able to send tokens to the empty contract");
    }
}
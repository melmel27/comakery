pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";
import "./support/UserProxy.sol";

contract TransferRestrictionsTest {
    ERC1404 token;
    address tokenContractOwner;
    UserProxy public alice;
    UserProxy public bob;

    uint256 groupA = 1;
    uint256 groupB = 2;
    uint256 transferTimeIsNow = now;
    uint maxTokens = 1000;

    function beforeEach() public {
        tokenContractOwner = address(this);
        token = new ERC1404(tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);

        alice = new UserProxy(token);
        bob = new UserProxy(token);

        token.setRestrictions(address(alice), groupA, transferTimeIsNow, maxTokens);
        token.setRestrictions(address(bob), groupB, transferTimeIsNow, maxTokens);
    }

    function testTransferRestrictionsBetweenUsersNotOnWhitelist() public {
        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), maxTokens + 1);
        Assert.equal(uint(restrictionCode), 1, "should fail if max balance would be exceeded in transfer");
    }

    function testRestrictedByDefault() public {       
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 7, "approved transfers should not work before groups are not approved");
    }

    function testGroupsWithoutTransferAuthorizationFaileTransfer() public {
        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow + 1 days);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 8, "approved transfers should not work before the specified time");
    }
    function testGroupsWithApprovedTransfersTransfer() public {
        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 0, "approved transfers should work after the specified time");
    }

    function testReverseOfTransferApprovalIsNotApproved() public {
        token.setAllowGroupTransfer(groupA, groupB, transferTimeIsNow);
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(alice), 17); // reversed transfer direction!
        Assert.equal(uint(restrictionCode), 7, "approved transfers should not work when transfer between groups is not approved");
    }

        function testCannotSendToTokenContractItself() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(token), 17);
        Assert.equal(uint(restrictionCode), 3, "should not be able to send tokens to the contract itself");
    }

    function testCannotSendToAddressZero() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(0), 17);
        Assert.equal(uint(restrictionCode), 4, "should not be able to send tokens to the empty contract");
    }
}
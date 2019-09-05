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
        token = new ERC1404(tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);

        alice = new UserProxy(token);
        bob = new UserProxy(token);

        token.setAccountPermissions(address(alice), groupA, transferTimeIsNow, maxTokens);
        token.setAccountPermissions(address(bob), groupB, transferTimeIsNow, maxTokens);
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

    function testMessageForTransferRestrictionSuccess() public {
        Assert.equal(token.messageForTransferRestriction(0), "SUCCESS", "wrong message");
        Assert.equal(token.messageForTransferRestriction(1), "GREATER THAN RECIPIENT MAX BALANCE", "wrong message");
        Assert.equal(token.messageForTransferRestriction(2), "SENDER TOKENS LOCKED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(3), "DO NOT SEND TO TOKEN CONTRACT", "wrong message");
        Assert.equal(token.messageForTransferRestriction(4), "DO NOT SEND TO EMPTY ADDRESS", "wrong message");
        Assert.equal(token.messageForTransferRestriction(5), "SENDER ADDRESS IS FROZEN", "wrong message");
        Assert.equal(token.messageForTransferRestriction(6), "ALL TRANSFERS PAUSED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(7), "TRANSFER GROUP NOT APPROVED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(8), "TRANSFER GROUP NOT ALLOWED UNTIL LATER", "wrong message");
    }
}
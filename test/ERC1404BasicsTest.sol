pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";
import "./support/UserProxy.sol";

contract ERC1404BasicsTest {
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

    function testTokenInitialization() public {
        Assert.equal(token.symbol(), "xyz", "should return the token symbol");
        Assert.equal(token.name(), "Ex Why Zee", "should return the token name");

        Assert.equal(uint(token.decimals()), 6, "should return the token decimals");
        Assert.equal(uint(token.totalSupply()), 1234567, "should return the totalSupply");
        Assert.equal(token.contractOwner(), tokenContractOwner, "wrong contract owner");
        Assert.equal(token.MAX_UINT(), uint(0) - uint(1), "MAX_UINT shoudld be largest possible uint256");
    }

    function testInitialTokenHolderGetsTotalSupply() public {
        Assert.isTrue(token.totalSupply() > 1, "there should be tokens issued");

        Assert.equal(uint(token.totalSupply()),
            token.balanceOf(tokenContractOwner),
            "all the tokens should be in the tokenContractOwner address");
    }

    function testTransferRestrictionSuccess() public {
        uint8 restrictionCode = token.detectTransferRestriction(tokenContractOwner, tokenContractOwner, 17);
        Assert.equal(uint(restrictionCode), 0, "not the transfer SUCCESS code");
    }

    function testMessageForTransferRestrictionSuccess() public {
        Assert.equal(token.messageForTransferRestriction(0), "SUCCESS", "wrong message");
        Assert.equal(token.messageForTransferRestriction(1), "RECIPIENT NOT APPROVED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(2), "SENDER TOKENS LOCKED", "wrong message");
        Assert.equal(token.messageForTransferRestriction(3), "DO NOT SEND TO TOKEN CONTRACT", "wrong message");
        Assert.equal(token.messageForTransferRestriction(4), "DO NOT SEND TO EMPTY ADDRESS", "wrong message");
        Assert.equal(token.messageForTransferRestriction(5), "SENDER ADDRESS IS FROZEN", "wrong message");
        Assert.equal(token.messageForTransferRestriction(6), "ALL TRANSFERS PAUSED", "wrong message");
    }

    function testTransferRestrictionsBetweenUsersNotOnWhitelist() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 1, "should restrict transfer between not whitelisted addresses");
    }

    function testCannotSendToTokenContractItself() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(token), 17);
        Assert.equal(uint(restrictionCode), 3, "should not be able to send tokens to the contract itself");
    }

    function testCannotSendToAddressZero() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(0), 17);
        Assert.equal(uint(restrictionCode), 4, "should not be able to send tokens to the empty contract");
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
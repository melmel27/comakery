pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";

contract UserProxy {
    ERC1404 public token;
    constructor(ERC1404 _token) public {
        token = _token;
    }

    function transfer(address to, uint amount) public returns(bool success) {
        return transfer(to, amount);
    }

    function setReceiveTransferStatus(address _account, bool _updatedValue) public {
        token.setReceiveTransferStatus(_account, _updatedValue);
    }
}

contract ERC1404Test {
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
        string memory message = token.messageForTransferRestriction(0);
        Assert.equal(message, "SUCCESS", "wrong message for success");
    }

    function testTransferRestrictionsBetweenUsersNotOnWhitelist() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 1, "should restrict transfer between not whitelisted addresses");
    }

    function testAdminCanAddAccountToWhitelistAndBeApprovedForTransfer() public {
        token.setReceiveTransferStatus(address(chuck), true);
        Assert.equal(token.getReceiveTransfersStatus(address(chuck)), true, "chuck should be able to receive transfers");
        
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 0, "should allow transfer to whitelisted addresses");
    }

    function testAdminCanRemoveAccountFromTheWhitelistAndBeApprovedForTransfer() public {
        token.setReceiveTransferStatus(address(chuck), true);
        token.setReceiveTransferStatus(address(chuck), false);
        Assert.equal(token.getReceiveTransfersStatus(address(chuck)), false, "chuck should be able to receive transfers");
        
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 1, "should have been removed from whitelist");
    }

    function testAdminCanLockupTokensForASpecificTime() public {
        uint lockupTill = now + 10000;
        token.lockUntil(address(alice), lockupTill);
        Assert.equal(token.getLockup(address(alice)), lockupTill, "not locked up as expected");

        token.setReceiveTransferStatus(address(bob), true);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 2, "should have tokens locked");
    }

    function testAdminCanLockupTokensForTheLongestTimePossible() public {
        token.lock(address(alice));
        Assert.equal(token.getLockup(address(alice)), token.MAX_UINT(), "not locked up as expected");

        token.setReceiveTransferStatus(address(bob), true);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 2, "should have tokens locked");
    }
    

     function testAdminCanUnlockTokens() public {
        uint lockupTill = now + 10000;
        token.lockUntil(address(alice), lockupTill);
        token.setReceiveTransferStatus(address(bob), true);
        token.unlock(address(alice));

        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 0, "should not have tokens locked");
    }
}
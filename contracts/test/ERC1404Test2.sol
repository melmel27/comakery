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

    function setApprovedReceiver(address _account, bool _updatedValue) public {
        token.setApprovedReceiver(_account, _updatedValue);
    }

}

contract ERC1404Test2 {
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

    function testAdminCanAddAccountToWhitelistAndBeApprovedForTransfer() public {
        token.setApprovedReceiver(address(chuck), true);
        Assert.equal(token.getApprovedReceiver(address(chuck)), true, "chuck should be able to receive transfers");
        
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 0, "should allow transfer to whitelisted addresses");
    }

    function testAdminCanRemoveAccountFromTheWhitelistAndBeApprovedForTransfer() public {
        token.setApprovedReceiver(address(chuck), true);
        token.setApprovedReceiver(address(chuck), false);
        Assert.equal(token.getApprovedReceiver(address(chuck)), false, "chuck should be able to receive transfers");
        
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 1, "should have been removed from whitelist");
    }

    function testAdminCanLockupTokensForASpecificTime() public {
        uint lockupTill = now + 10000;
        token.lockUntil(address(alice), lockupTill);
        Assert.equal(token.getLockup(address(alice)), lockupTill, "not locked up as expected");

        token.setApprovedReceiver(address(bob), true);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 2, "should have tokens locked");
    }

    function testAdminCanLockupTokensForTheLongestTimePossible() public {
        token.lock(address(alice));
        Assert.equal(token.getLockup(address(alice)), token.MAX_UINT(), "not locked up as expected");

        token.setApprovedReceiver(address(bob), true);
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 2, "should have tokens locked");
    }
    
     function testAdminCanUnlockTokens() public {
        uint lockupTill = now + 10000;
        token.lockUntil(address(alice), lockupTill);
        token.setApprovedReceiver(address(bob), true);
        token.unlock(address(alice));

        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        Assert.equal(uint(restrictionCode), 0, "should not have tokens locked");
    }

    function testCannotSendToTokenContractItself() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(token), 17);
        Assert.equal(uint(restrictionCode), 3, "should not be able to send tokens to the contract itself");
    }

    function testCannotSendToZero() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), address(0), 17);
        Assert.equal(uint(restrictionCode), 4, "should not be able to send tokens to the empty contract");
    }
}
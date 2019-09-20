pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/RestrictedToken.sol";
import "./support/UserProxy.sol";

contract MaxReceiverBalanceTest {
    RestrictedToken token;
    address tokenContractOwner;
    UserProxy public alice;
    UserProxy public bob;
    address reserveAdmin;

    function beforeEach() public {
        tokenContractOwner = address(this);
        reserveAdmin = address(0x1);
        token = new RestrictedToken(tokenContractOwner, reserveAdmin, "xyz", "Ex Why Zee", 6, 1234567);
        token.grantTransferAdmin(tokenContractOwner);
        
        alice = new UserProxy(token);
        bob = new UserProxy(token);

        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testAdminCanAddAccountToWhitelistAndBeApprovedForTransfer() public {       
        byte restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        

        token.setMaxBalance(address(bob), 10);
        restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 10);
        Assert.equal(restrictionCode, hex"00", "should allow max value");

        token.setMaxBalance(address(bob), 0);
        restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 10);
        Assert.equal(restrictionCode, hex"01", "should not allow a value transfer above the max for the recipient address");
    }

    function testGetMaxBalance() public {
        Assert.equal(token.getMaxBalance(address(alice)), 0, "wrong balance for alice");
        token.setMaxBalance(address(alice), 10);
        Assert.equal(token.getMaxBalance(address(alice)), 10, "wrong balance for alice");
    }
}
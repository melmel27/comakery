pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/RestrictedToken.sol";

contract GettersAndSettersTest {
    using Assert for uint256;
    using Assert for bool;

    RestrictedToken public token;
    address public owner;
    

    function beforeEach() public {
        owner = address(this);
        token = new RestrictedToken(owner, owner, "xyz", "Ex Why Zee", 0, 100);
        token.grantTransferAdmin(owner);
    }

    function testGettersAndSetters() public {
        uint number = token.balanceOf(owner);
        number.equal(100, "bad getter value");

        number = token.maxBalances(owner);
        number.equal(0, "bad getter value");

        number = token.timeLock(owner);
        number.equal(0, "bad getter value");

        number = token.transferGroups(owner);
        number.equal(0, "bad getter value");
    
        Assert.equal(token.frozen(owner), false, "default is not frozen");
    }

    function testCheckingAllowGroupTransfers() public {
        uint defaultGroup = 0;
        bool allowed = token.getAllowGroupTransfer(defaultGroup, defaultGroup, now);
        allowed.isFalse("should not allow transfers between groups by default");

        token.setAllowGroupTransfer(defaultGroup,defaultGroup,1); // allow transfers in default group 1 second after the start of time
        token.getAllowGroupTransfer(defaultGroup,defaultGroup,now).isTrue("should allow transfer after first second of all time");
    }

    function testCheckingAllowGroupTransfersWithAddresses() public {
        address alice = address(0x1);
        address bob = address(0x2);
        
        bool allowed = token.getAllowTransfer(alice, bob, now);
        allowed.isFalse("should not allow transfers between groups by default");
    }

    function testGetAllowTransferTime() public {
        address alice = address(0x1);
        address bob = address(0x2);
        token.getAllowTransferTime(alice, bob).equal(0, "default to time 0 for all addresses");

        // allow alice and bob's default group (0) to trade after timestamp 100
        token.setAllowGroupTransfer(0,0,100);  
        token.getAllowTransferTime(alice, bob).equal(100, "transfer group timestamp not properly set");
    }
}
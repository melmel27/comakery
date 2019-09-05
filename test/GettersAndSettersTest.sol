pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "./support/UserProxy.sol";
import "../contracts/ERC1404.sol";

contract GettersAndSettersTest {
    using Assert for uint256;
    using Assert for bool;

    ERC1404 public token;
    address public owner;
    

    function beforeEach() public {
        owner = address(this);
        token = new ERC1404(owner, "xyz", "Ex Why Zee", 0, 100);        
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

    function testTransferRestrictions() public {
        bool allowed = token.getAllowGroupTransfer(0,0,now);
        allowed.isFalse("bad getter value");

        token.allowGroupTransfer(0,0,1);
        token.getAllowGroupTransfer(0,0,now).isTrue("should allow transfer after first second of all time");
    }
}
pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";
import "./support/UserProxy.sol";

contract MaxReceiverBalanceTest {
    ERC1404 token;
    address tokenContractOwner;
    UserProxy public alice;
    UserProxy public bob;

    function beforeEach() public {
        tokenContractOwner = address(this);
        token = new ERC1404(tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);

        alice = new UserProxy(token);
        bob = new UserProxy(token);
    }

    function testAdminCanAddAccountToWhitelistAndBeApprovedForTransfer() public {       
        uint8 restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 17);
        

        token.setMaxBalance(address(bob), 10);
        restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 10);
        Assert.equal(uint(restrictionCode), 0, "should allow max value");

        token.setMaxBalance(address(bob), 0);
        restrictionCode = token.detectTransferRestriction(address(alice), address(bob), 10);
        Assert.equal(uint(restrictionCode), 1, "should not allow a value transfer above the max for the recipient address");
    }
}
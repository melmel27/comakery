pragma solidity 0.5.12;

import "truffle/Assert.sol";
import "../../contracts/RestrictedToken.sol";
import "../../contracts/TransferRules.sol";

contract FreezeTest {
    RestrictedToken public token;
    address tokenContractOwner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);

    function beforeEach() public {
        TransferRules rules = new TransferRules();
        token = new RestrictedToken(address(rules), tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 100, 1e6);

        token.revokeReserveAdmin(address(this)); // removing the role given by the constructor

        token.grantWalletsAdmin(address(this));
        token.setMaxBalance(alice, 1000);
        token.setMaxBalance(address(bob), 100);
        token.revokeWalletsAdmin(address(this));

        token.grantTransferAdmin(address(this));
        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testFreezeReserveAdmin() public {
        token.grantReserveAdmin(address(this));

        token.transfer(alice, 10);
        token.freeze(alice, true);

        uint8 code = token.detectTransferRestriction(alice, address(bob), 1);
        Assert.equal(uint256(code), 5, "wrong transfer restriction code for frozen account");

        Assert.equal(token.transferRules().messageForTransferRestriction(code), 
        "SENDER ADDRESS IS FROZEN", "wrong transfer restriction code for frozen account");
    }

    function testFreezeWalletsAdmin() public {
        token.grantWalletsAdmin(address(this));

        token.transfer(alice, 10);
        token.freeze(alice, true);

        uint8 code = token.detectTransferRestriction(alice, address(bob), 1);
        Assert.equal(uint256(code), 5, "wrong transfer restriction code for frozen account");

        Assert.equal(token.transferRules().messageForTransferRestriction(code), 
        "SENDER ADDRESS IS FROZEN", "wrong transfer restriction code for frozen account");
    }

    function testCanPauseTransfers() public {
        Assert.isFalse(token.isPaused(), "should not be paused yet");
        token.pause();
        Assert.isTrue(token.isPaused(), "should be paused");
        uint8 restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), alice, 1);
        Assert.equal(uint(restrictionCode), 6, "should not be able to transfer when contract is paused");

        token.unpause();
        Assert.isFalse(token.isPaused(), "should be unpaused");
        restrictionCode = token.detectTransferRestriction(address(tokenContractOwner), alice, 1);
        Assert.equal(uint(restrictionCode), 0, "should be able to transfer when contract is unpaused");
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/RestrictedToken.sol";
import "../../contracts/TransferRules.sol";
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
        TransferRules rules = new TransferRules();
        token = new RestrictedToken(
            address(rules),
            tokenContractOwner,
            tokenContractOwner,
            "xyz",
            "Ex Why Zee",
            0,
            100,
            1e6
        );
        token.grantTransferAdmin(tokenContractOwner);
        token.grantWalletsAdmin(tokenContractOwner);

        alice = new UserProxy(token);
        bob = new UserProxy(token);

        token.setAllowGroupTransfer(0, 0, block.timestamp); // don't restrict default group transfers
    }

    function testAdminCanAddAccountToWhitelistAndBeApprovedForTransfer()
        public
    {
        uint8 restrictionCode = token.detectTransferRestriction(
            address(alice),
            address(bob),
            17
        );

        token.setMaxBalance(address(bob), 10);
        restrictionCode = token.detectTransferRestriction(
            address(alice),
            address(bob),
            10
        );
        Assert.equal(uint256(restrictionCode), 0, "should allow max value");

        token.setMaxBalance(address(bob), 1);
        restrictionCode = token.detectTransferRestriction(
            address(alice),
            address(bob),
            10
        );
        Assert.equal(
            uint256(restrictionCode),
            1,
            "should not allow a value transfer above the max for the recipient address"
        );
    }

    function testGetMaxBalance() public {
        Assert.equal(
            token.getMaxBalance(address(alice)),
            0,
            "wrong balance for alice"
        );
        token.setMaxBalance(address(alice), 10);
        Assert.equal(
            token.getMaxBalance(address(alice)),
            10,
            "wrong balance for alice"
        );
    }
}

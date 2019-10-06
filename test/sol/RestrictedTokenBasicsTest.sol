pragma solidity 0.5.12;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/RestrictedToken.sol";
import "../../contracts/TransferRules.sol";
import "./support/UserProxy.sol";

contract RestrictedTokenBasicsTest {
    RestrictedToken token;
    address tokenContractOwner;
    address reserveAdmin;

    function beforeEach() public {
        tokenContractOwner = address(this);

        reserveAdmin = address(0x1);
        TransferRules rules = new TransferRules();
        token = new RestrictedToken(
            address(rules),
            tokenContractOwner,
            reserveAdmin,
            "xyz",
            "Ex Why Zee",
            6,
            1234567
        );
        token.grantTransferAdmin(tokenContractOwner);

        token.setMaxBalance(tokenContractOwner, 1e18);
        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testTokenInitialization() public {
        Assert.equal(token.symbol(), "xyz", "should return the token symbol");
        Assert.equal(
            token.name(),
            "Ex Why Zee",
            "should return the token name"
        );
        Assert.equal(
            uint256(token.decimals()),
            6,
            "should return the token decimals"
        );
        Assert.equal(
            uint256(token.totalSupply()),
            1234567,
            "should return the totalSupply"
        );
        Assert.equal(
            token.MAX_UINT(),
            uint256(0) - uint256(1),
            "MAX_UINT should be largest possible uint256"
        );
    }

    function testTokenAdminSetup() public {
        Assert.isTrue(token.totalSupply() > 1, "there should be tokens issued");
        Assert.equal(
            token.balanceOf(tokenContractOwner),
            0,
            "contract owner should get 0 balance"
        );
        Assert.equal(
            token.balanceOf(address(reserveAdmin)),
            token.totalSupply(),
            "reserve admin should get the initial token balance"
        );
    }

    function testTransferRestrictionSuccess() public {
        uint8 restrictionCode = token.detectTransferRestriction(
            tokenContractOwner,
            tokenContractOwner,
            17
        );
        Assert.equal(
            uint256(restrictionCode),
            0,
            "not the transfer SUCCESS code"
        );
    }

    function testTotalSupply() public {
        Assert.equal(
            token.totalSupply(),
            uint256(1234567),
            "billion tokens to start"
        );
    }

    function testBalanceOf() public {
        uint256 balance = token.balanceOf(address(reserveAdmin));
        Assert.equal(balance, token.totalSupply(), "correct initial balance");
    }

    function testApproveReturnValue() public {
        address someone = address(0x7);
        bool result = token.approve(someone, 10);
        Assert.equal(result, false, "response should always be false to encourage use of safeApprove");
        Assert.equal(
            token.allowance(tokenContractOwner, someone),
            10,
            "should have correct allowance"
        );
    }
}

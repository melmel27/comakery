pragma solidity ^0.5.8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";
import "./support/UserProxy.sol";

contract ERC1404BasicsTest {
    ERC1404 token;
    address tokenContractOwner;
    address reserveAdmin;

    function beforeEach() public {
        tokenContractOwner = address(this);
        reserveAdmin = address(0x1);
        token = new ERC1404(tokenContractOwner, reserveAdmin, "xyz", "Ex Why Zee", 6, 1234567);
        token.setAllowGroupTransfer(0, 0, now); // don't restrict default group transfers
    }

    function testTokenInitialization() public {
        Assert.equal(token.symbol(), "xyz", "should return the token symbol");
        Assert.equal(token.name(), "Ex Why Zee", "should return the token name");
        Assert.equal(uint(token.decimals()), 6, "should return the token decimals");
        Assert.equal(uint(token.totalSupply()), 1234567, "should return the totalSupply");
        Assert.equal(token.contractOwner(), tokenContractOwner, "wrong contract owner");
        Assert.equal(token.MAX_UINT(), uint(0) - uint(1), "MAX_UINT should be largest possible uint256");        
    }

    function testTokenAdminSetup() public {
        Assert.isTrue(token.totalSupply() > 1, "there should be tokens issued");
        Assert.equal(token.contractOwner(), tokenContractOwner, "contract owner should be assigned");
        Assert.equal(token.balanceOf(tokenContractOwner), 0, "contract owner should get 0 balance");
        Assert.equal(token.balanceOf(address(reserveAdmin)), token.totalSupply(), "reserve admin should get the initial token balance");
    }

    function testTransferRestrictionSuccess() public {
        uint8 restrictionCode = token.detectTransferRestriction(tokenContractOwner, tokenContractOwner, 17);
        Assert.equal(uint(restrictionCode), 0, "not the transfer SUCCESS code");
    }
}
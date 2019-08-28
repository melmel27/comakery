pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ERC1404.sol";

contract ERC1404Test {
    ERC1404 token;
    address initialTokenHolder;

    function beforeEach() public {
        initialTokenHolder = address(this);
        token = new ERC1404(initialTokenHolder, "xyz", "Ex Why Zee", 6, 1234567);
    }

    function testTokenInitialization() public {
        Assert.equal(token.symbol(), "xyz", "should return the token symbol");
        Assert.equal(token.name(), "Ex Why Zee", "should return the token name");

        Assert.equal(uint(token.decimals()), 6, "should return the token decimals");
        Assert.equal(uint(token.totalSupply()), 1234567, "should return the totalSupply");

    }

    function testInitialTokenHolderGetsTotalSupply() public {
        Assert.isTrue(token.totalSupply() > 1, "there should be tokens issued");

        Assert.equal(uint(token.totalSupply()),
            token.balanceOf(initialTokenHolder),
            "all the tokens should be in the initialTokenHolder address");
    }
}
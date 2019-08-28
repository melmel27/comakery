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
}

contract ERC1404Test {
    ERC1404 token;
    address initialTokenHolder;
    UserProxy public alice;
    UserProxy public bob;
    UserProxy public chuck;
    

    function beforeEach() public {
        alice = new UserProxy(token);
        bob = new UserProxy(token);
        chuck = new UserProxy(token);

        initialTokenHolder = address(alice);
        token = new ERC1404(initialTokenHolder, "xyz", "Ex Why Zee", 6, 1234567);
    }

    function testTokenInitialization() public {
        Assert.equal(token.symbol(), "xyz", "should return the token symbol");
        Assert.equal(token.name(), "Ex Why Zee", "should return the token name");

        Assert.equal(uint(token.decimals()), 6, "should return the token decimals");
        Assert.equal(uint(token.totalSupply()), 1234567, "should return the totalSupply");
        Assert.equal(token.contractOwner(), initialTokenHolder, "wrong contract owner");
    }

    function testInitialTokenHolderGetsTotalSupply() public {
        Assert.isTrue(token.totalSupply() > 1, "there should be tokens issued");

        Assert.equal(uint(token.totalSupply()),
            token.balanceOf(initialTokenHolder),
            "all the tokens should be in the initialTokenHolder address");
    }

    function testTransferRestrictionSuccess() public {
        uint8 restrictionCode = token.detectTransferRestriction(initialTokenHolder, initialTokenHolder, 1);
        Assert.equal(uint(restrictionCode), 0, "not the transfer SUCCESS code");
    }

    function testMessageForTransferRestrictionSuccess() public {
        string memory message = token.messageForTransferRestriction(0);
        Assert.equal(message, "SUCCESS", "wrong message for success");
    }
}
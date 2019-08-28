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

    function allowReceiveTransfers(address _account, bool _updatedValue) public {
        token.allowReceiveTransfers(_account, _updatedValue);
    }
}

contract ERC1404Test {
    ERC1404 token;
    address tokenContractOwner;
    UserProxy public alice;
    UserProxy public bob;
    UserProxy public chuck;

    function beforeEach() public {
        alice = new UserProxy(token); // alice owns the contract and gets all the tokens first
        bob = new UserProxy(token);
        chuck = new UserProxy(token);

        tokenContractOwner = address(this);
        token = new ERC1404(tokenContractOwner, "xyz", "Ex Why Zee", 6, 1234567);
    }

    function testTokenInitialization() public {
        Assert.equal(token.symbol(), "xyz", "should return the token symbol");
        Assert.equal(token.name(), "Ex Why Zee", "should return the token name");

        Assert.equal(uint(token.decimals()), 6, "should return the token decimals");
        Assert.equal(uint(token.totalSupply()), 1234567, "should return the totalSupply");
        Assert.equal(token.contractOwner(), tokenContractOwner, "wrong contract owner");
    }

    function testInitialTokenHolderGetsTotalSupply() public {
        Assert.isTrue(token.totalSupply() > 1, "there should be tokens issued");

        Assert.equal(uint(token.totalSupply()),
            token.balanceOf(tokenContractOwner),
            "all the tokens should be in the tokenContractOwner address");
    }

    function testTransferRestrictionSuccess() public {
        uint8 restrictionCode = token.detectTransferRestriction(tokenContractOwner, tokenContractOwner, 17);
        Assert.equal(uint(restrictionCode), 0, "not the transfer SUCCESS code");
    }

    function testMessageForTransferRestrictionSuccess() public {
        string memory message = token.messageForTransferRestriction(0);
        Assert.equal(message, "SUCCESS", "wrong message for success");
    }

    function testTransferRestrictionsBetweenUsersNotOnWhitelist() public {
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 1, "should restrict transfer between not whitelisted addresses");
    }

    function testAdminCanAddAccountToWhitelistAndBeApprovedForTransfer() public {
        token.allowReceiveTransfers(address(chuck), true);
        Assert.equal(token.getReceiveTransfersStatus(address(chuck)), true, "chuck should be able to receive transfers");
        
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 0, "should allow transfer to whitelisted addresses");
    }

    function testAdminCanRemoveAccountFromTheWhitelistAndBeApprovedForTransfer() public {
        token.allowReceiveTransfers(address(chuck), true);
        token.allowReceiveTransfers(address(chuck), false);
        Assert.equal(token.getReceiveTransfersStatus(address(chuck)), false, "chuck should be able to receive transfers");
        
        uint8 restrictionCode = token.detectTransferRestriction(address(bob), address(chuck), 17);
        Assert.equal(uint(restrictionCode), 1, "should have removed from whitelist");
    }
}
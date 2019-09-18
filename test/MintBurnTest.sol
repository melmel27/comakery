pragma solidity ^ 0.5 .8;

import "truffle/Assert.sol";
import "../contracts/RestrictedToken.sol";

contract MintBurnTest {
    RestrictedToken public token;
    address alice = address(0x1);

    function beforeEach() public {
        token = new RestrictedToken(address(this), address(this), "xyz", "Ex Why Zee", 6, 100);
        token.grantTransferAdmin(address(this));

    }

    function testCannotMintMoreThanMaxUintValue() public {
        (bool success, ) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", alice, token.MAX_UINT()));
        Assert.isFalse(success, "should fail because it exceeds the max uint256 value");
    }
}
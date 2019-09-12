// Out of gas errors... need to move this to Javascript

// pragma solidity ^ 0.5 .8;

// import "truffle/Assert.sol";
// import "../contracts/RestrictedToken.sol";

// contract MintBurnTest {
//     RestrictedToken public token;
//     address tokenContractOwner = address(this);
//     address alice = address(0x1);

//     function beforeEach() public {

//         // tokenContractOwner = address(this);
//         token = new RestrictedToken(tokenContractOwner, tokenContractOwner, "xyz", "Ex Why Zee", 6, 100);
//         token.grantTransferAdmin(tokenContractOwner);

//         // alice = address(0x1);
//     }

//     function testBurn() public {
//         Assert.equal(token.balanceOf(tokenContractOwner), 100, "wrong balance for owner");
//         token.transfer(alice, 17);

//         Assert.equal(token.totalSupply(), 100, "incorrect total supply");
//         Assert.equal(token.balanceOf(alice), 17, "wrong balance for alice");

//         token.burnFrom(alice, 17);
//         Assert.equal(token.balanceOf(alice), 0, "wrong balance for alice");
//         Assert.equal(token.totalSupply(), 83, "incorrect total supply");
//     }

//     function testCannotBurnMoreThanAddressBalance() public {
//         token.setMaxBalance(alice, 1000);
//         token.setAllowGroupTransfer(0, 0, now);

//         token.transfer(alice, 10);
//         (bool success, ) = address(token).call(abi.encodeWithSignature("burnFrom(address,uint256)", alice, 11));
//         Assert.isFalse(success, "should fail to burn if address does not have enough balance to burn");

//         Assert.equal(token.totalSupply(), 100, "incorrect total supply");
//         Assert.equal(token.balanceOf(alice), 10, "wrong balance for alice");
//     }

//     function testMint() public {
//         Assert.equal(token.balanceOf(tokenContractOwner), 100, "wrong balance for owner");
//         Assert.equal(token.balanceOf(alice), 0, "wrong balance for owner");
//         Assert.equal(token.totalSupply(), 100, "incorrect total supply");

//         token.mint(alice, 10);

//         Assert.equal(token.balanceOf(alice), 10, "wrong balance for owner");
//         Assert.equal(token.totalSupply(), 110, "incorrect total supply");
//     }

//     function testCannotMintMoreThanMaxUintValue() public {
//         (bool success, ) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", alice, token.MAX_UINT()));
//         Assert.isFalse(success, "should fail because it exceeds the max uint256 value");
//     }
// }
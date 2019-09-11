var ERC1404 = artifacts.require("ERC1404");

contract("Access control tests", function(accounts) {
  var owner;
  var reserveAdmin;
  var token;
  beforeEach(async function() {
    owner = accounts[0]
    reserveAdmin = accounts[1]
    token = await ERC1404.new(owner, reserveAdmin, "xyz", "Ex Why Zee", 6, 100);
  })

  it("sets up contract correctly based on constructor arguments", async () => {
    assert.equal(await token.symbol.call(), "xyz")
    assert.equal(await token.name.call(), "Ex Why Zee")
    assert.equal(await token.decimals.call(), 6)
    assert.equal(await token.totalSupply.call(), 100)
    assert.equal(await token.contractOwner.call(), owner, 'sets the owner')
    assert.equal(await token.balanceOf.call(owner), 0, 'allocates no balance to the owner')
    assert.notEqual(await token.contractOwner.call(), reserveAdmin, 'sets the owner')
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
  })
})
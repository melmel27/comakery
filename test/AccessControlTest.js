var RestrictedToken = artifacts.require("RestrictedToken");

contract("Access control tests", function(accounts) {
  var owner
  var reserveAdmin
  var unprivileged
  var token

  beforeEach(async function() {
    owner = accounts[0]
    reserveAdmin = accounts[1]
    unprivileged = accounts[5]

    token = await RestrictedToken.new(owner, reserveAdmin, "xyz", "Ex Why Zee", 6, 100);
  })
  
  it('contract owner is not the same address as treasury admin', async () => {
    assert.equal(await token.contractOwner.call(), owner, 'sets the owner')
    assert.equal(await token.balanceOf.call(owner), 0, 'allocates no balance to the owner')
    assert.notEqual(await token.contractOwner.call(), reserveAdmin, 'sets the owner')
    assert.equal(await token.balanceOf.call(reserveAdmin), 100, 'allocates all tokens to the token reserve admin')
  })

  it("an unprivileged user can call the public getter functions", async () => {
    assert.equal(await token.symbol.call({from: unprivileged}), "xyz")
    assert.equal(await token.name.call({from: unprivileged}), "Ex Why Zee")
    assert.equal(await token.decimals.call({from: unprivileged}), 6)
    assert.equal(await token.totalSupply.call({from: unprivileged}), 100)
    assert.equal(await token.contractOwner.call({from: unprivileged}), owner, 'sets the owner')
    assert.equal(await token.balanceOf.call(owner, {from: unprivileged}), 0, 'allocates no balance to the owner')
    assert.equal(await token.balanceOf.call(reserveAdmin, {from: unprivileged}), 100, 'allocates all tokens to the token reserve admin')
  })
  
  it("an unprivileged user can check transfer restrictions", async () => {
    assert.equal(await token.detectTransferRestriction
      .call(owner, reserveAdmin, 1, {from: unprivileged}), 1)

    assert.equal(await token.messageForTransferRestriction.call(1, {from: unprivileged}), "GREATER THAN RECIPIENT MAX BALANCE")
  })
})
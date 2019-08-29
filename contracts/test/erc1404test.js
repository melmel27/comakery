var ERC1404 = artifacts.require("ERC1404");

contract("ERC1404", function(accounts) {
  it("should assert true", function(done) {
    var e_r_c1404 = ERC1404.deployed();
    assert.isTrue(true);
    done();
  });
});

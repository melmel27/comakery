const truffleAssert = require('truffle-assertions');
const RestrictedSwap = artifacts.require('RestrictedSwap')
const Erc20 = artifacts.require('Erc20Mock')

contract('RestrictedSwap', function (accounts) {
  before(async () => {
    this.owner = accounts[0]
    this.admins = accounts.slice(1, 3)

    this.erc1404 = await Erc20.new('1404', '1404')
    this.token2 = await Erc20.new('20', '20')
    this.restrictedSwap = await RestrictedSwap.new(this.erc1404.address, this.admins, this.owner)
  })
})

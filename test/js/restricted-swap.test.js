const { expect } = require('chai')
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers')
const RestrictedSwap = artifacts.require('RestrictedSwap')
const Erc20 = artifacts.require('Erc20Mock')
const Erc1404 = artifacts.require('RestrictedToken')
const TransferRules = artifacts.require("TransferRules")

contract('RestrictedSwap', function (accounts) {
  beforeEach(async () => {
    this.owner = accounts[0]
    this.swapAdmins = accounts.slice(1, 2)
    
    this.contractAdmin = accounts[3]
    this.reserveAdmin = accounts[4]
    
    this.rules = await TransferRules.new()
    this.erc1404 = await Erc1404.new(
      this.rules.address,
      this.contractAdmin,
      this.reserveAdmin,
      'xyz',
      'ex why xyz',
      6,
      10000,
      10000
    )
    this.token2 = await Erc20.new('20', '20')
    this.restrictedSwap = await RestrictedSwap.new(
      this.erc1404.address,
      this.swapAdmins,
      this.owner
    )
    
    this.restrictedTokenSender = accounts[5]
    this.restrictedTokenAmount = 10
    this.token2Sender = accounts[6]
    this.token2Amount = 15

    const transferLockedUntil = new BN(Math.floor(Date.now() / 1000))
    await this.erc1404.grantTransferAdmin(accounts[3], { from: this.contractAdmin })
    await this.erc1404.setAllowGroupTransfer(0, 0, transferLockedUntil, { from: accounts[3] })
    this.swapReceipt = await this.restrictedSwap.configureSwap(
      this.restrictedTokenSender,
      this.restrictedTokenAmount,
      this.token2.address,
      this.token2Sender,
      this.token2Amount,
      { from: this.swapAdmins[0] }
    )
  })

  it('Swap configuration returns swap number', async () => {
    expectEvent(this.swapReceipt, 'SwapConfigured', { swapNumber: new BN(1) })
  })

  describe('Only owner can grant and revoke admin', async () => {
    it('Non-owner fails to grant and revoke admin', async () => {
      await expectRevert(
        this.restrictedSwap.grantAdmin(accounts[2], { from: accounts[1] }),
        'Not owner'
      )

      await expectRevert(
        this.restrictedSwap.revokeAdmin(accounts[1], { from: accounts[1] }),
        'Not owner'
      )
    })

    it('Owner succeeds to grant admin', async () => {
      await this.restrictedSwap.grantAdmin(accounts[3], { from: this.owner })
    })
  })

  describe('Configuring swap fails when', async () => {
    it('called by non-admin', async () => {
      await expectRevert(
        this.restrictedSwap.configureSwap(
          this.restrictedTokenSender,
          this.restrictedTokenAmount,
          this.token2.address,
          this.token2Sender,
          this.token2Amount,
          { from: accounts[0] }
        ),
        'Not admin'
      )
    })

    it('restricted token is not approved to swap', async () => {
      await this.erc1404.freeze(this.restrictedTokenSender, true, { from: this.reserveAdmin })
      await expectRevert(
        this.restrictedSwap.configureSwap(
          this.restrictedTokenSender,
          this.restrictedTokenAmount,
          this.token2.address,
          this.token2Sender,
          this.token2Amount,
          { from: this.swapAdmins[0] }
        ),
        'SENDER ADDRESS IS FROZEN'
      )
    })

    it('token2 is ERC1404 and it is not approved to swap', async () => {
      const token2 = await Erc1404.new(
        this.rules.address,
        this.contractAdmin,
        this.reserveAdmin,
        'xyz',
        'ex why xyz',
        6,
        10000,
        10000
      )
      await token2.freeze(this.restrictedTokenSender, true, { from: this.reserveAdmin })
      await expectRevert(
        this.restrictedSwap.configureSwap(
          this.restrictedTokenSender,
          this.restrictedTokenAmount,
          token2.address,
          this.token2Sender,
          this.token2Amount,
          { from: this.swapAdmins[0] }
        ),
        'RECIPIENT ADDRESS IS FROZEN'
      )
    })
  })
})

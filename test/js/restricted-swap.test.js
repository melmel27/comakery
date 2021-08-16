const { expect } = require('chai')
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers')
const RestrictedSwap = artifacts.require('RestrictedSwap')
const Erc20 = artifacts.require('Erc20Mock')
const Erc20TxFee = artifacts.require('Erc20TxFeeMock')
const Erc1404 = artifacts.require('Erc1404Mock')
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
    this.restrictedTokenAmount = new BN(10)
    this.token2Sender = accounts[6]
    this.token2Amount = new BN(15)

    await Promise.all([
      this.erc1404.mintToken(9999, { from: this.restrictedTokenSender }),
      this.token2.mint(9999, { from: this.token2Sender }),
      this.erc1404.approve(
        this.restrictedSwap.address,
        9999,
        { from: this.restrictedTokenSender }
      ),
      this.token2.approve(
        this.restrictedSwap.address,
        9999,
        { from: this.token2Sender }
      ),
    ])

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

  describe('New configuration', async () => {
    it('returns swap number', async () => {
      expectEvent(this.swapReceipt, 'SwapConfigured', { swapNumber: new BN(1) })
    })
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

  describe('Funding restricted token to swap', async () => {
    it('succeeds', async () => {
      const funderBalance = await this.erc1404.balanceOf(this.restrictedTokenSender)
      const swapBalance = await this.erc1404.balanceOf(this.restrictedSwap.address)
      await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })

      expect((await this.erc1404.balanceOf(this.restrictedTokenSender)).toNumber())
        .to.equal(funderBalance.sub(this.restrictedTokenAmount).toNumber())
      expect((await this.erc1404.balanceOf(this.restrictedSwap.address)).toNumber())
        .to.equal(swapBalance.add(this.restrictedTokenAmount).toNumber())
    })

    it('fails when already funded', async () => {
      await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })
      await expectRevert(
        this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender }),
        'This swap has already been funded'
      )
    })

    it('fails in case of incorrect funder', async () => {
      await expectRevert(
        this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: accounts[0] }),
        'You are not appropriate token sender for this swap'
      )
    })
  })

  describe('Funding token2 to swap', async () => {
    it('succeeds', async () => {
      const funderBalance = await this.token2.balanceOf(this.token2Sender)
      const swapBalance = await this.token2.balanceOf(this.restrictedSwap.address)
      await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })

      expect((await this.token2.balanceOf(this.token2Sender)).toNumber())
        .to.equal(funderBalance.sub(this.token2Amount).toNumber())
      expect((await this.token2.balanceOf(this.restrictedSwap.address)).toNumber())
        .to.equal(swapBalance.add(this.token2Amount).toNumber())
    })

    it('fails when already funded', async () => {
      await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })
      await expectRevert(
        this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender }),
        'This swap has already been funded'
      )
    })

    it('fails in case of incorrect funder', async () => {
      await expectRevert(
        this.restrictedSwap.fundToken2Swap(new BN(1), { from: accounts[0] }),
        'You are not appropriate token sender for this swap'
      )
    })
  })

  describe('Swap', async () => {
    it('succeeds', async () => {
      const token1BalanceOfFunder1 = await this.erc1404.balanceOf(this.restrictedTokenSender)
      const token1BalanceOfFunder2 = await this.erc1404.balanceOf(this.token2Sender)
      const token2BalanceOfFunder1 = await this.token2.balanceOf(this.restrictedTokenSender)
      const token2BalanceOfFunder2 = await this.token2.balanceOf(this.token2Sender)
  
      await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })
      await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })
  
      expect((await this.erc1404.balanceOf(this.restrictedTokenSender)).toNumber())
        .to.equal(token1BalanceOfFunder1.sub(this.restrictedTokenAmount).toNumber())
      expect((await this.erc1404.balanceOf(this.token2Sender)).toNumber())
        .to.equal(token1BalanceOfFunder2.add(this.restrictedTokenAmount).toNumber())
      expect((await this.token2.balanceOf(this.restrictedTokenSender)).toNumber())
        .to.equal(token2BalanceOfFunder1.add(this.token2Amount).toNumber())
      expect((await this.token2.balanceOf(this.token2Sender)).toNumber())
        .to.equal(token2BalanceOfFunder2.sub(this.token2Amount).toNumber())
    })
  })

  describe('Cancel check', async () => {
    it('only admin can cancel if no parties funded', async () => {
      await expectRevert(
        this.restrictedSwap.cancelSwap(new BN(1), { from : accounts[0] }),
        'Only admin can cancel the swap'
      )
      await this.restrictedSwap.cancelSwap(new BN(1), { from : this.swapAdmins[0] })
    })

    describe('only admin and restricted token funder can cancel if swap is funded from restricted token funder', async () => {
      it('admin can cancel the swap funded from restricted token funder', async () => {
        const balance = await this.erc1404.balanceOf(this.restrictedTokenSender)
        await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })
        await this.restrictedSwap.cancelSwap(new BN(1), { from : this.swapAdmins[0] })
        expect((await this.erc1404.balanceOf(this.restrictedTokenSender)).toNumber())
          .to.equal(balance.toNumber())
      })

      it('restricted token funder can cancel the swap funded from restricted token funder', async () => {
        const balance = await this.erc1404.balanceOf(this.restrictedTokenSender)
        await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })
        await this.restrictedSwap.cancelSwap(new BN(1), { from : this.restrictedTokenSender })
        expect((await this.erc1404.balanceOf(this.restrictedTokenSender)).toNumber())
          .to.equal(balance.toNumber())
      })

      it('no other one can cancel the swap funded from restricted token funder', async () => {
        await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })
        await expectRevert(
          this.restrictedSwap.cancelSwap(new BN(1), { from : accounts[0] }),
          'Only admin or restricted token sender can cancel the swap'
        )
      })
    })

    describe('only admin and token2 funder can cancel if swap is funded from token2 funder', async () => {
      it('admin can cancel the swap funded from token2 funder', async () => {
        const balance = await this.token2.balanceOf(this.token2Sender)
        await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })
        await this.restrictedSwap.cancelSwap(new BN(1), { from : this.swapAdmins[0] })
        expect((await this.token2.balanceOf(this.token2Sender)).toNumber())
          .to.equal(balance.toNumber())
      })

      it('token2 funder can cancel the swap funded from token2 funder', async () => {
        const balance = await this.token2.balanceOf(this.token2Sender)
        await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })
        await this.restrictedSwap.cancelSwap(new BN(1), { from : this.token2Sender })
        expect((await this.token2.balanceOf(this.token2Sender)).toNumber())
          .to.equal(balance.toNumber())
      })

      it('no other one can cancel the swap funded from token2 funder', async () => {
        await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })
        await expectRevert(
          this.restrictedSwap.cancelSwap(new BN(1), { from : accounts[0] }),
          'Only admin or token2 sender can cancel the swap'
        )
      })
    })

    it('cannot cancel with an invalid swap number', async () => {
      await expectRevert(
        this.restrictedSwap.cancelSwap(new BN(2), { from : accounts[0] }),
        'This swap is not configured'
      )
    })

    it('cannot cancel swap that has been funded from both parties', async () => {
      await this.restrictedSwap.fundRestrictedTokenSwap(new BN(1), { from: this.restrictedTokenSender })
      await this.restrictedSwap.fundToken2Swap(new BN(1), { from: this.token2Sender })
      await expectRevert(
        this.restrictedSwap.cancelSwap(new BN(1), { from : this.swapAdmins[0] }),
        'Cannot cancel completed swap'
      )
    })

    it('cannot cancel again', async () => {
      await this.restrictedSwap.cancelSwap(new BN(1), { from : this.swapAdmins[0] })
      await expectRevert(
        this.restrictedSwap.cancelSwap(new BN(1), { from : this.swapAdmins[0] }),
        'Already canceled'
      )
    })
  })

  describe('Check deposit revert with token with transaction fee', async () => {
    let erc20TxFee = null

    beforeEach(async () => {
      erc20TxFee = await Erc20TxFee.new('20', '20')

      await Promise.all([
        erc20TxFee.mint(9999, { from: this.token2Sender }),
        erc20TxFee.approve(
          this.restrictedSwap.address,
          9999,
          { from: this.token2Sender }
        ),
      ])

      await this.restrictedSwap.configureSwap(
        this.restrictedTokenSender,
        this.restrictedTokenAmount,
        erc20TxFee.address,
        this.token2Sender,
        this.token2Amount,
        { from: this.swapAdmins[0] }
      )
    })

    it('deposit reverts and funder balance gets restored', async () => {
      const senderBalance = await erc20TxFee.balanceOf(this.token2Sender)
      const swapBalance = await erc20TxFee.balanceOf(this.restrictedSwap.address)

      await expectRevert(
        this.restrictedSwap.fundToken2Swap(new BN(2), { from: this.token2Sender }),
        'Deposit reverted for incorrect result of deposited amount'
      )

      expect((await erc20TxFee.balanceOf(this.token2Sender)).toNumber())
        .to.equal(senderBalance.toNumber())
      expect((await erc20TxFee.balanceOf(this.restrictedSwap.address)).toNumber())
        .to.equal(swapBalance.toNumber())
    })

    it('check event emits', async () => {
      /*
       * this test won't work because event and revert are done in the same transaction...
       * will need to find another way
       */
      // const swapReceipt = await this.restrictedSwap.fundToken2Swap(new BN(2), { from: this.token2Sender })
      // expectEvent(
      //   swapReceipt,
      //   'IncorrectDepositResult',
      // )
    })
  })
})

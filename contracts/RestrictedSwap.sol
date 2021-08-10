// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRestrictedSwap } from "./interfaces/IRestrictedSwap.sol";

contract RestrictedSwap is IRestrictedSwap, AccessControl {
  
  struct Swap {
    address sender;
    uint amount;
    bool processed;
  }

  using SafeERC20 for IERC20;

  /// @dev admin role
  bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  /// @dev address of comakery security token of erc1404 type
  address private immutable _erc1404;

  /// @dev
  uint private _swapNumber = 0;

  /// @dev erc1404 swap
  mapping(uint => Swap) private _swapErc1404;

  /// @dev token2 swap
  mapping(uint => address) private _swapToken2Address;
  mapping(uint => Swap) private _swapToken2;

  /// @dev canceled
  mapping(uint => bool) private _swapCanceled;

  event SwapCanceled(address sender, uint swapNumber);

  /**
   *  @dev Constructor
   *  @param erc1404 comakery security token address
   *  @param admins admin addresses are granted admin roles
   *  @param owner owner address is granted the owner role for the contract and he can add or remove admins
   */
  constructor(
    address erc1404,
    address[] memory admins,
    address owner
  ) {
    require(owner != address(0), "Invalid owner address");

    _erc1404 = erc1404;
    _setupRole(DEFAULT_ADMIN_ROLE, owner);

    for (uint i = 0; i < admins.length; i++) {
      _setupRole(ADMIN_ROLE, admins[i]);
    }
  }

  /**
   *  @dev Configure swap
   *  @param restrictedTokenSender the approved sender for the erc1404, the erc1404 is the only one assigned to the RestrictedSwap
   *  @param restrictedTokenAmount the required amount for the erc1404Sender to send
   *  @param token2 the address of an erc1404 or erc20 that will be swapped
   *  @param token2Sender the address that is approved to fund token2
   *  @param token2Amount the required amount of token2 to swap
   *  @return _swapNumber swap number
   */
  function configureSwap(
    address restrictedTokenSender,
    uint restrictedTokenAmount,
    address token2,
    address token2Sender,
    uint token2Amount
  ) external
    override
    onlyRole(ADMIN_ROLE)
    returns(uint)
  {
    require(restrictedTokenSender != address(0), "Invalid restricted token sender");
    require(restrictedTokenAmount > 0, "Invalid restricted token amount");
    require(token2Sender != address(0), "Invalid token2 sender");
    require(token2Amount > 0, "Invalid token2 amount");
    require(token2 != address(0), "Invalid token2 address");

    _swapNumber += 1;

    _swapErc1404[_swapNumber].sender = restrictedTokenSender;
    _swapErc1404[_swapNumber].amount = restrictedTokenAmount;

    _swapToken2[_swapNumber].sender = token2Sender;
    _swapToken2[_swapNumber].amount = token2Amount;
    _swapToken2Address[_swapNumber] = token2;

    return _swapNumber;
  }

  /**
   *  @dev restricted token swap for erc1404
   *  @param swapNumber swap number
   */
  function fundRestrictedTokenSwap(uint swapNumber) external override {
    Swap storage swap = _swapErc1404[swapNumber];
    uint allowance = IERC20(_erc1404).allowance(msg.sender, address(this));

    require(!swap.processed, "This swap has already been funded");
    require(!_swapCanceled[swapNumber], "This swap has been canceled");
    require(swap.sender != msg.sender, "You are not appropriate restricted token sender for this swap");
    require(allowance >= swap.amount, "Insufficient allownace to transfer token");

    IERC20(_erc1404).safeTransferFrom(msg.sender, address(this), swap.amount);
    swap.processed = true;

    if (_swapToken2[swapNumber].processed) {
      _swap(
        swap.sender,
        swap.amount,
        _swapToken2Address[swapNumber],
        _swapToken2[swapNumber].sender,
        _swapToken2[swapNumber].amount
      );
    }
  }

  /**
   *  @dev token2 swap
   *  @param swapNumber swap number
   */
  function fundToken2Swap(uint swapNumber) external override {
    Swap storage swap = _swapToken2[swapNumber];
    address token2 = _swapToken2Address[swapNumber];
    uint allowance = IERC20(token2).allowance(msg.sender, address(this));

    require(!swap.processed, "This swap has already been funded");
    require(!_swapCanceled[swapNumber], "This swap has been canceled");
    require(swap.sender != msg.sender, "You are not appropriate token2 sender for this swap");
    require(token2 != address(0), "Invalid token2 address");
    require(allowance >= swap.amount, "Insufficient allowance to transfer token");

    IERC20(token2).safeTransferFrom(msg.sender, address(this), swap.amount);
    swap.processed = true;

    if (_swapErc1404[swapNumber].processed) {
      _swap(
        _swapErc1404[swapNumber].sender,
        _swapErc1404[swapNumber].amount,
        token2,
        swap.sender,
        swap.amount
      );
    }
  }

    /**
   *  @dev cancel swap
   *  @param swapNumber swap number
   */
  function cancelSwap(uint swapNumber) external override {
    Swap storage swapErc1404 = _swapErc1404[swapNumber];
    Swap storage swapToken2 = _swapToken2[swapNumber];

    require(!_swapCanceled[swapNumber], "Already canceled");
    require(swapErc1404.sender != address(0), "This swap is not configured");
    require(swapToken2.sender != address(0), "This swap is not configured");
    require(
      !swapErc1404.processed || !swapToken2.processed,
      "Cannot cancel as both parties funded"
    );

    if (!swapErc1404.processed) {
      if (!swapToken2.processed) {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin can cancel the swap");
        _swapCanceled[swapNumber] = true;
      } else {
        require(
          hasRole(ADMIN_ROLE, msg.sender) || swapToken2.sender == msg.sender,
          "Only admin or token2 sender can cancel the swap"
        );
        IERC20(_swapToken2Address[swapNumber]).safeTransfer(swapToken2.sender, swapToken2.amount);
        _swapCanceled[swapNumber] = true;
        emit SwapCanceled(swapToken2.sender, swapNumber);
      }
    } else if (!swapToken2.processed) {
      require(
        hasRole(ADMIN_ROLE, msg.sender) || swapErc1404.sender == msg.sender,
        "Only admin or restricted token sender can cancel the swap"
      );
      IERC20(_erc1404).safeTransfer(swapErc1404.sender, swapErc1404.amount);
      _swapCanceled[swapNumber] = true;
      emit SwapCanceled(swapErc1404.sender, swapNumber);
    }
  }

  /**
   *  @dev swap erc1404 and token2
   *  @param restrictedTokenSender address
   *  @param restrictedTokenAmount uint
   *  @param token2 address
   *  @param token2Sender address
   *  @param token2Amount uint
   */
  function _swap(
    address restrictedTokenSender,
    uint restrictedTokenAmount,
    address token2,
    address token2Sender,
    uint token2Amount
  ) internal {
    IERC20(_erc1404).safeTransfer(token2Sender, restrictedTokenAmount);
    IERC20(token2).safeTransfer(restrictedTokenSender, token2Amount);
  }

  /**
   *  @dev Grant admin role to user specified by `account`
   *  @param account user address to which grant admin role
   */
  function grantAdmin(address account)
    override
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    grantRole(ADMIN_ROLE, account);
  }

  /**
   *  @dev Revoke admin role from user specified by `account`
   *  @param account user address from which revoke admin role
   */
  function revokeAdmin(address account)
    override
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    revokeRole(ADMIN_ROLE, account);
  }
}

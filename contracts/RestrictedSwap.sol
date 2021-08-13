// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRestrictedSwap } from "./interfaces/IRestrictedSwap.sol";
import { IERC1404 } from "./interfaces/IERC1404.sol";

contract RestrictedSwap is IRestrictedSwap, AccessControl {
  
  struct Swap {
    address restrictedTokenSender;
    address token2Sender;
    address token2;
    uint restrictedTokenAmount;
    uint token2Amount;
    bool fundRestrictedToken;
    bool fundToken2;
    bool canceled;
  }

  using SafeERC20 for IERC20;

  /// @dev admin role
  bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  /// @dev address of comakery security token of erc1404 type
  address private immutable _erc1404;

  /// @dev
  uint private _swapNumber = 0;

  /// @dev swap number => swap
  mapping(uint => Swap) private _swap;

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
    
    uint8 code = IERC1404(_erc1404).detectTransferRestriction(
      restrictedTokenSender,
      token2Sender,
      restrictedTokenAmount);
    string memory message = IERC1404(_erc1404).messageForTransferRestriction(code);
    require(code == 0, message);

    bytes memory data = abi.encodeWithSelector(
      IERC1404(token2).detectTransferRestriction.selector,
      token2Sender,
      restrictedTokenSender,
      token2Amount);
    (bool isErc1404, bytes memory returnData) = token2.call(data);

    if (isErc1404) {
      code = abi.decode(returnData, (uint8));
      message = IERC1404(token2).messageForTransferRestriction(code);
      require(code == 0, message);
    }

    _swapNumber += 1;

    _swap[_swapNumber].restrictedTokenSender = restrictedTokenSender;
    _swap[_swapNumber].restrictedTokenAmount = restrictedTokenAmount;
    _swap[_swapNumber].token2Sender = token2Sender;
    _swap[_swapNumber].token2Amount = token2Amount;
    _swap[_swapNumber].token2 = token2;

    return _swapNumber;
  }

  /**
   *  @dev restricted token swap for erc1404
   *  @param swapNumber swap number
   */
  function fundRestrictedTokenSwap(uint swapNumber) external override {
    Swap storage swap = _swap[swapNumber];
    uint allowance = IERC20(_erc1404).allowance(msg.sender, address(this));

    require(!swap.fundRestrictedToken, "This swap has already been funded");
    require(!swap.canceled, "This swap has been canceled");
    require(swap.restrictedTokenSender == msg.sender, "You are not appropriate restricted token sender for this swap");
    require(allowance >= swap.restrictedTokenAmount, "Insufficient allownace to transfer token");

    IERC20(_erc1404).safeTransferFrom(msg.sender, address(this), swap.restrictedTokenAmount);
    swap.fundRestrictedToken = true;

    if (swap.fundToken2) {
      IERC20(_erc1404).safeTransfer(swap.token2Sender, swap.restrictedTokenAmount);
      IERC20(swap.token2).safeTransfer(swap.restrictedTokenSender, swap.token2Amount);
    }
  }

  /**
   *  @dev token2 swap
   *  @param swapNumber swap number
   */
  function fundToken2Swap(uint swapNumber) external override {
    Swap storage swap = _swap[swapNumber];
    uint allowance = IERC20(swap.token2).allowance(msg.sender, address(this));

    require(!swap.fundToken2, "This swap has already been funded");
    require(!swap.canceled, "This swap has been canceled");
    require(swap.token2Sender == msg.sender, "You are not appropriate token2 sender for this swap");
    require(swap.token2 != address(0), "Invalid token2 address");
    require(allowance >= swap.token2Amount, "Insufficient allowance to transfer token");

    IERC20(swap.token2).safeTransferFrom(msg.sender, address(this), swap.token2Amount);
    swap.fundToken2 = true;

    if (swap.fundRestrictedToken) {
      IERC20(_erc1404).safeTransfer(swap.token2Sender, swap.restrictedTokenAmount);
      IERC20(swap.token2).safeTransfer(swap.restrictedTokenSender, swap.token2Amount);
    }
  }

    /**
   *  @dev cancel swap
   *  @param swapNumber swap number
   */
  function cancelSwap(uint swapNumber) external override {
    Swap storage swap = _swap[swapNumber];

    require(!swap.canceled, "Already canceled");
    require(swap.restrictedTokenSender != address(0), "This swap is not configured");
    require(swap.token2Sender != address(0), "This swap is not configured");
    require(
      !swap.fundRestrictedToken || !swap.fundToken2,
      "Cannot cancel as both parties funded"
    );

    if (!swap.fundRestrictedToken) {
      if (!swap.fundToken2) {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin can cancel the swap");
        swap.canceled = true;
      } else {
        require(
          hasRole(ADMIN_ROLE, msg.sender) || swap.token2Sender == msg.sender,
          "Only admin or token2 sender can cancel the swap"
        );
        IERC20(swap.token2).safeTransfer(swap.token2Sender, swap.token2Amount);
        swap.canceled = true;
        emit SwapCanceled(swap.token2Sender, swapNumber);
      }
    } else if (!swap.fundToken2) {
      require(
        hasRole(ADMIN_ROLE, msg.sender) || swap.restrictedTokenSender == msg.sender,
        "Only admin or restricted token sender can cancel the swap"
      );
      IERC20(_erc1404).safeTransfer(swap.restrictedTokenSender, swap.restrictedTokenAmount);
      swap.canceled = true;
      emit SwapCanceled(swap.restrictedTokenSender, swapNumber);
    }
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

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
    uint256 restrictedTokenAmount;
    uint256 token2Amount;
    bool fundRestrictedToken;
    bool fundToken2;
    bool canceled;
  }

  using SafeERC20 for IERC20;

  /// @dev owner role
  bytes32 private constant OWNER_ROLE = DEFAULT_ADMIN_ROLE;

  /// @dev admin role
  bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  /// @dev address of comakery security token of erc1404 type
  address private immutable _erc1404;

  /// @dev swap number
  uint256 private _swapNumber = 0;

  /// @dev swap number => swap
  mapping(uint256 => Swap) private _swap;

  event SwapCanceled(address sender, uint256 swapNumber);

  event SwapConfigured(
    uint256 swapNumber,
    address restrictedTokenSender,
    uint256 restrictedTokenAmount,
    address token2,
    address token2Sender,
    uint256 token2Amount
  );

  event IncorrectDepositResult(
    uint256 swapNumber,
    address restrictedTokenSender,
    address token2Sender
  );

  modifier onlyAdmin() {
    require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
    _;
  }

  modifier onlyOwner() {
    require(hasRole(OWNER_ROLE, msg.sender), "Not owner");
    _;
  }

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
    _setupRole(OWNER_ROLE, owner);

    for (uint256 i = 0; i < admins.length; i++) {
      _setupRole(ADMIN_ROLE, admins[i]);
    }
  }

  /**
   *  @dev Configure swap and emit an event with new swap number
   *  @param restrictedTokenSender the approved sender for the erc1404, the erc1404 is the only one assigned to the RestrictedSwap
   *  @param restrictedTokenAmount the required amount for the erc1404Sender to send
   *  @param token2 the address of an erc1404 or erc20 that will be swapped
   *  @param token2Sender the address that is approved to fund token2
   *  @param token2Amount the required amount of token2 to swap
   */
  function configureSwap(
    address restrictedTokenSender,
    uint256 restrictedTokenAmount,
    address token2,
    address token2Sender,
    uint256 token2Amount
  ) external
    override
    onlyAdmin
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

    Swap storage swap = _swap[_swapNumber];
    swap.restrictedTokenSender = restrictedTokenSender;
    swap.restrictedTokenAmount = restrictedTokenAmount;
    swap.token2Sender = token2Sender;
    swap.token2Amount = token2Amount;
    swap.token2 = token2;

    emit SwapConfigured(
      _swapNumber,
      restrictedTokenSender,
      restrictedTokenAmount,
      token2,
      token2Sender,
      token2Amount
    );
  }

  /**
   *  @dev restricted token swap for erc1404
   *  @param swapNumber swap number
   */
  function fundRestrictedTokenSwap(uint256 swapNumber) external override {
    Swap storage swap = _swap[swapNumber];
    uint256 allowance = IERC20(_erc1404).allowance(msg.sender, address(this));

    require(!swap.fundRestrictedToken, "This swap has already been funded");
    require(!swap.canceled, "This swap has been canceled");
    require(swap.restrictedTokenSender == msg.sender, "You are not appropriate token sender for this swap");
    require(allowance >= swap.restrictedTokenAmount, "Insufficient allownace to transfer token");

    uint256 balanceBefore = IERC20(_erc1404).balanceOf(address(this));
    IERC20(_erc1404).safeTransferFrom(msg.sender, address(this), swap.restrictedTokenAmount);
    uint256 balanceAfter = IERC20(_erc1404).balanceOf(address(this));

    if (balanceBefore + swap.restrictedTokenAmount != balanceAfter) {
      emit IncorrectDepositResult(
        swapNumber,
        swap.restrictedTokenSender,
        swap.token2Sender
      );
      revert("Deposit reverted for incorrect result of deposited amount");
    }

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
  function fundToken2Swap(uint256 swapNumber) external override {
    Swap storage swap = _swap[swapNumber];
    uint256 allowance = IERC20(swap.token2).allowance(msg.sender, address(this));

    require(!swap.fundToken2, "This swap has already been funded");
    require(!swap.canceled, "This swap has been canceled");
    require(swap.token2Sender == msg.sender, "You are not appropriate token sender for this swap");
    require(swap.token2 != address(0), "Invalid token2 address");
    require(allowance >= swap.token2Amount, "Insufficient allowance to transfer token");

    uint256 balanceBefore = IERC20(swap.token2).balanceOf(address(this));
    IERC20(swap.token2).safeTransferFrom(msg.sender, address(this), swap.token2Amount);
    uint256 balanceAfter = IERC20(swap.token2).balanceOf(address(this));

    if (balanceBefore + swap.token2Amount != balanceAfter) {
      emit IncorrectDepositResult(
        swapNumber,
        swap.restrictedTokenSender,
        swap.token2Sender
      );
      revert("Deposit reverted for incorrect result of deposited amount");
    }

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
  function cancelSwap(uint256 swapNumber) external override {
    Swap storage swap = _swap[swapNumber];

    require(!swap.canceled, "Already canceled");
    require(swap.restrictedTokenSender != address(0), "This swap is not configured");
    require(swap.token2Sender != address(0), "This swap is not configured");
    require(
      !swap.fundRestrictedToken || !swap.fundToken2,
      "Cannot cancel completed swap"
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
    onlyOwner
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
    onlyOwner
  {
    revokeRole(ADMIN_ROLE, account);
  }
}

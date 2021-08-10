// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IRestrictedSwap {
  /**
   *  @dev Configure swap
   *  @param restrictedTokenSender the approved sender for the erc1404, the erc1404 is the only one assigned to the RestrictedSwap
   *  @param restrictedTokenAmount the required amount for the erc1404Sender to send
   *  @param token2 the address of an erc1404 or erc20 that will be swapped
   *  @param token2Address the address that is approved to fund token2
   *  @param token2Amount the required amount of token2 to swap
   */
  function configureSwap(
    address restrictedTokenSender,
    uint restrictedTokenAmount,
    address token2,
    address token2Address,
    uint token2Amount
  ) external returns(uint swapNumber);

  /**
   *  @dev restricted token swap for erc1404
   *  @param swapNumber swap number
   */
  function fundRestrictedTokenSwap(uint swapNumber) external;

  /**
   *  @dev token2 swap
   *  @param swapNumber swap number
   */
  function fundToken2Swap(uint swapNumber) external;

  /**
   *  @dev cancel swap
   *  @param swapNumber swap number
   */
  function cancelSwap(uint swapNumber) external;

  /**
   *  @dev Grant admin role to user specified by `account`
   *  @param account user address to which grant admin role
   */
  function grantAdmin(address account) external;

  /**
   *  @dev Revoke admin role from user specified by `account`
   *  @param account user address from which revoke admin role
   */
  function revokeAdmin(address account) external;
}

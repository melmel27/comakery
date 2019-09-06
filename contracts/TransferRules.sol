pragma solidity ^ 0.5 .8;
import './ERC1404.sol';
import './ITransferRules.sol';

contract TransferRules is ITransferRules {
    uint8 public constant SUCCESS = 0;
    uint8 public constant GREATER_THAN_RECIPIENT_MAX_BALANCE = 1;
    uint8 public constant SENDER_TOKENS_TIME_LOCKED = 2;
    uint8 public constant DO_NOT_SEND_TO_TOKEN_CONTRACT = 3;
    uint8 public constant DO_NOT_SEND_TO_EMPTY_ADDRESS = 4;
    uint8 public constant SENDER_ADDRESS_FROZEN = 5;
    uint8 public constant ALL_TRANSFERS_PAUSED = 6;
    uint8 public constant TRANSFER_GROUP_NOT_APPROVED = 7;
    uint8 public constant TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER = 8;

    /******* ERC1404 FUNCTIONS ***********/

  /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
  /// @param from Sending address
  /// @param to Receiving address
  /// @param value Amount of tokens being transferred
  /// @return Code by which to reference message for rejection reasoning
  function detectTransferRestriction(ERC1404 token, address from, address to, uint256 value) public view returns(uint8) {
    if (token.isPaused()) return ALL_TRANSFERS_PAUSED;
    if (to == address(0)) return DO_NOT_SEND_TO_EMPTY_ADDRESS;
    if (to == address(token)) return DO_NOT_SEND_TO_TOKEN_CONTRACT;

    if (value > token.getMaxBalance(to)) return GREATER_THAN_RECIPIENT_MAX_BALANCE;
    if (now < token.getTimeLock(from)) return SENDER_TOKENS_TIME_LOCKED;
    if (token.frozen(from)) return SENDER_ADDRESS_FROZEN;

    uint256 _allowedTransferTime = token.getAllowTransferTime(from, to);
    if (0 == _allowedTransferTime) return TRANSFER_GROUP_NOT_APPROVED;
    if (now < _allowedTransferTime) return TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER;

    return SUCCESS;
  }

  /// @notice Returns a human-readable message for a given restriction code
  /// @param restrictionCode Identifier for looking up a message
  /// @return Text showing the restriction's reasoning
  function messageForTransferRestriction(uint8 restrictionCode) public pure returns(string memory) {
    return ["SUCCESS",
      "GREATER THAN RECIPIENT MAX BALANCE",
      "SENDER TOKENS LOCKED",
      "DO NOT SEND TO TOKEN CONTRACT",
      "DO NOT SEND TO EMPTY ADDRESS",
      "SENDER ADDRESS IS FROZEN",
      "ALL TRANSFERS PAUSED",
      "TRANSFER GROUP NOT APPROVED",
      "TRANSFER GROUP NOT ALLOWED UNTIL LATER"
    ][restrictionCode];
  }
}
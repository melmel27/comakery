pragma solidity 0.5.12;
import './RestrictedToken.sol';
import './ITransferRules.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TransferRules is ITransferRules {
    using SafeMath for uint256;
    mapping(uint8 => string) internal errorMessage;

    uint8 public constant SUCCESS = 0;
    uint8 public constant GREATER_THAN_RECIPIENT_MAX_BALANCE = 1;
    uint8 public constant SENDER_TOKENS_TIME_LOCKED = 2;
    uint8 public constant DO_NOT_SEND_TO_TOKEN_CONTRACT = 3;
    uint8 public constant DO_NOT_SEND_TO_EMPTY_ADDRESS = 4;
    uint8 public constant SENDER_ADDRESS_FROZEN = 5;
    uint8 public constant ALL_TRANSFERS_PAUSED = 6;
    uint8 public constant TRANSFER_GROUP_NOT_APPROVED = 7;
    uint8 public constant TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER = 8;

  constructor() public {
    errorMessage[SUCCESS] = "SUCCESS";
    errorMessage[GREATER_THAN_RECIPIENT_MAX_BALANCE] = "GREATER THAN RECIPIENT MAX BALANCE";
    errorMessage[SENDER_TOKENS_TIME_LOCKED] = "SENDER TOKENS LOCKED";
    errorMessage[DO_NOT_SEND_TO_TOKEN_CONTRACT] = "DO NOT SEND TO TOKEN CONTRACT";
    errorMessage[DO_NOT_SEND_TO_EMPTY_ADDRESS] = "DO NOT SEND TO EMPTY ADDRESS";
    errorMessage[SENDER_ADDRESS_FROZEN] = "SENDER ADDRESS IS FROZEN";
    errorMessage[ALL_TRANSFERS_PAUSED] = "ALL TRANSFERS PAUSED";
    errorMessage[TRANSFER_GROUP_NOT_APPROVED] = "TRANSFER GROUP NOT APPROVED";
    errorMessage[TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER] = "TRANSFER GROUP NOT ALLOWED UNTIL LATER";
  }

  /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
  /// @param from Sending address
  /// @param to Receiving address
  /// @param value Amount of tokens being transferred
  /// @return Code by which to reference message for rejection reasoning
  function detectTransferRestriction(address _token, address from, address to, uint256 value) external view returns(uint8) {
    RestrictedToken token = RestrictedToken(_token);
    if (token.isPaused()) return ALL_TRANSFERS_PAUSED;
    if (to == address(0)) return DO_NOT_SEND_TO_EMPTY_ADDRESS;
    if (to == address(token)) return DO_NOT_SEND_TO_TOKEN_CONTRACT;

    if (token.balanceOf(to).add(value) > token.getMaxBalance(to)) return GREATER_THAN_RECIPIENT_MAX_BALANCE;
    if (now < token.getLockUntil(from)) return SENDER_TOKENS_TIME_LOCKED;
    if (token.getFrozenStatus(from)) return SENDER_ADDRESS_FROZEN;

    uint256 lockedUntil = token.getAllowTransferTime(from, to);
    if (0 == lockedUntil) return TRANSFER_GROUP_NOT_APPROVED;
    if (now < lockedUntil) return TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER;

    return SUCCESS;
  }

  /// @notice Returns a human-readable message for a given restriction code
  /// @param restrictionCode Identifier for looking up a message
  /// @return Text showing the restriction's reasoning
  function messageForTransferRestriction(uint8 restrictionCode) external view returns(string memory) {
    return errorMessage[restrictionCode];
  }

  function checkSuccess(uint8 restrictionCode) external view returns(bool) {
    return restrictionCode == SUCCESS;
  }
}
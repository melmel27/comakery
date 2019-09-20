pragma solidity ^ 0.5 .8;
import './RestrictedToken.sol';
import './ITransferRules.sol';

contract TransferRules is ITransferRules {
    mapping(byte => string) internal errorMessage;
    
    byte public constant SUCCESS = hex"00";
    byte public constant GREATER_THAN_RECIPIENT_MAX_BALANCE = hex"01";
    byte public constant SENDER_TOKENS_TIME_LOCKED = hex"02";
    byte public constant DO_NOT_SEND_TO_TOKEN_CONTRACT = hex"03";
    byte public constant DO_NOT_SEND_TO_EMPTY_ADDRESS = hex"04";
    byte public constant SENDER_ADDRESS_FROZEN = hex"05";
    byte public constant ALL_TRANSFERS_PAUSED = hex"06";
    byte public constant TRANSFER_GROUP_NOT_APPROVED = hex"07";
    byte public constant TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER = hex"08";

  constructor() public {
    // errorMessage[SUCCESS] = "SUCCESS";
    // errorMessage[GREATER_THAN_RECIPIENT_MAX_BALANCE] = "GREATER THAN RECIPIENT MAX BALANCE";
    // errorMessage[SENDER_TOKENS_TIME_LOCKED] = "SENDER TOKENS LOCKED";
    // errorMessage[DO_NOT_SEND_TO_TOKEN_CONTRACT] = "DO NOT SEND TO TOKEN CONTRACT";
    // errorMessage[DO_NOT_SEND_TO_EMPTY_ADDRESS] = "DO NOT SEND TO EMPTY ADDRESS";
    // errorMessage[SENDER_ADDRESS_FROZEN] = "SENDER ADDRESS IS FROZEN";
    // errorMessage[ALL_TRANSFERS_PAUSED] = "ALL TRANSFERS PAUSED";
    // errorMessage[TRANSFER_GROUP_NOT_APPROVED] = "TRANSFER GROUP NOT APPROVED";
    // errorMessage[TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER] = "TRANSFER GROUP NOT ALLOWED UNTIL LATER";
  }

  /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
  /// @param from Sending address
  /// @param to Receiving address
  /// @param value Amount of tokens being transferred
  /// @return Code by which to reference message for rejection reasoning
  function detectTransferRestriction(address _token, address from, address to, uint256 value) public view returns(byte) {
    RestrictedToken token = RestrictedToken(_token);
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
  function messageForTransferRestriction(byte restrictionCode) public view returns(string memory) {
    return errorMessage[restrictionCode];
  }
}
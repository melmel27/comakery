pragma solidity ^0.5.8;

contract ERC1404 {
  string public symbol;
  string public name;
  uint8 public decimals;
  uint256 public totalSupply;
  address public contractOwner;

  uint8 public constant SUCCESS = 0;
  uint8 public constant GREATER_THAN_RECIPIENT_MAX_BALANCE = 1;
  uint8 public constant SENDER_TOKENS_TIME_LOCKED = 2;
  uint8 public constant DO_NOT_SEND_TO_TOKEN_CONTRACT = 3;
  uint8 public constant DO_NOT_SEND_TO_EMPTY_ADDRESS = 4;
  uint8 public constant SENDER_ADDRESS_FROZEN = 5;
  uint8 public constant ALL_TRANSFERS_PAUSED = 6;
  uint8 public constant TRANSFER_GROUP_NOT_APPROVED = 7;
  uint8 public constant TRANSFER_GROUP_NOT_ALLOWED_UNTIL_LATER = 8;

  uint256 public constant MAX_UINT = ((2 ** 255 - 1) * 2) + 1; // get max uint256 without overflow

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowed;
  mapping(address => mapping(address => uint8)) private _approvalNonces;

  mapping(address => uint256) public maxBalances; // TODO: may want to map address => uint256 for max holdings
  mapping(address => uint256) public timeLock; // unix timestamp to lock funds until
  mapping(address => uint256) public transferGroups; // restricted groups like Reg S, Reg D and Reg CF
  mapping(uint256 => mapping(uint256 => uint256)) private _allowGroupTransfers; // approve transfers between groups: from => to => TimeLockUntil
  mapping(address => bool) public frozenAddresses;
  bool public isPaused = false;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  constructor(
    address _contractOwner,
    address _tokenReserveAdmin,
    string memory _symbol,
    string memory _name,
    uint8 _decimals,
    uint256 _totalSupply
  ) public {
    require(_contractOwner != address(0), "Token owner address cannot be 0x0");

    symbol = _symbol;
    name = _name;
    decimals = _decimals;

    contractOwner = _contractOwner;

    _balances[_tokenReserveAdmin] = _totalSupply;
    totalSupply = _balances[_tokenReserveAdmin];
  }

  /******* ERC1404 FUNCTIONS ***********/

  /// @notice Checks if a transfer is restricted, reverts if it is
  /// @param from Sending address
  /// @param to Receiving address
  /// @param value Amount of tokens being transferred
  /// @dev Defining this modifier is not required by the standard, using detectTransferRestriction and appropriately emitting TransferRestricted is however
  function enforceTransferRestrictions(address from, address to, uint256 value) public view {
    uint8 restrictionCode = detectTransferRestriction(from, to, value);
    require(restrictionCode == SUCCESS, messageForTransferRestriction(restrictionCode));
  }

  /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
  /// @param from Sending address
  /// @param to Receiving address
  /// @param value Amount of tokens being transferred
  /// @return Code by which to reference message for rejection reasoning
  function detectTransferRestriction(address from, address to, uint256 value) public view returns(uint8) {
    if (isPaused) return ALL_TRANSFERS_PAUSED;
    if (to == address(0)) return DO_NOT_SEND_TO_EMPTY_ADDRESS;
    if (to == address(this)) return DO_NOT_SEND_TO_TOKEN_CONTRACT;
    if (from == contractOwner) return SUCCESS;

    if (value > getMaxBalance(to)) return GREATER_THAN_RECIPIENT_MAX_BALANCE;
    if (now < getTimeLock(from)) return SENDER_TOKENS_TIME_LOCKED;
    if (frozen(from)) return SENDER_ADDRESS_FROZEN;

    uint256 _allowedTransferTime = getAllowTransferTime(from, to);
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

  function setMaxBalance(address _account, uint256 _updatedValue) public {
    maxBalances[_account] = _updatedValue;
  }

  function getMaxBalance(address _account) public view returns(uint256) {
    return maxBalances[_account];
  }

  // TODO: should timestamp 0 be locked? ie should tokens be locked by default? probably yes.
  function setTimeLock(address _account, uint256 _timestamp) public {
    timeLock[_account] = _timestamp;
  }

  function removeTimeLock(address _account) public {
    timeLock[_account] = 0;
  }

  function getTimeLock(address _account) public view returns(uint256) {
    return timeLock[_account];
  }

  function pause() public {
    isPaused = true;
  }

  function unpause() public {
    isPaused = false;
  }

  function setGroup(address addr, uint256 groupID) public {
    transferGroups[addr] = groupID;
  }

  function getTransferGroup(address addr) public view returns(uint256 groupID) {
    return transferGroups[addr];
  }

  function setAccountPermissions(address addr, uint256 groupID, uint256 timeLockUntil, uint256 maxTokens) public {
    setGroup(addr, groupID);
    setTimeLock(addr, timeLockUntil);
    setMaxBalance(addr, maxTokens);
  }

  function setAllowGroupTransfer(uint256 groupA, uint256 groupB, uint256 transferAfter) public {
    // TODO: if 0 no transfer; update README
    // TODO: if 1 any transfer works; update README
    _allowGroupTransfers[groupA][groupB] = transferAfter;
  }

  function getAllowGroupTransfer(uint256 from, uint256 to, uint256 timestamp) public view returns(bool) {
    if (_allowGroupTransfers[from][to] == 0) return false;
    return _allowGroupTransfers[from][to] < timestamp;
  }

  function getAllowTransfer(address from, address to, uint256 atTimestamp) public view returns(bool) {
    getAllowGroupTransfer(getTransferGroup(from), getTransferGroup(to), atTimestamp);
  }

  // note the transfer time default is 0 for transfers between all addresses
  // a transfer time of 0 is treated as not allowed
  function getAllowTransferTime(address from, address to) public view returns(uint timestamp) {
    return _allowGroupTransfers[transferGroups[from]][transferGroups[to]];
  }

  /******* Mint, Burn, Freeze ***********/
  // For Token owner

  function burnFrom(address from, uint256 value) public {
    require(value <= _balances[from], "Insufficent tokens to burn");
    _balances[from] = sub(_balances[from], value);
    totalSupply = sub(totalSupply, value);
  }

  function mint(address to, uint256 value) public {
    _balances[to] = add(_balances[to], value);
    totalSupply = add(totalSupply, value);
  }

  function freeze(address addr, bool status) public {
    frozenAddresses[addr] = status;
  }

  function frozen(address addr) public view returns(bool) {
    return frozenAddresses[addr];
  }
  /******* ERC20 FUNCTIONS ***********/

  function balanceOf(address owner) public view returns(uint256 balance) {
    return _balances[owner];
  }

  function allowance(address owner, address spender) public view returns(uint256 remaining) {
    return _allowed[owner][spender];
  }

  function transfer(address to, uint256 value) public returns(bool success) {
    enforceTransferRestrictions(msg.sender, to, value);
    _transfer(msg.sender, to, value);
    return true;
  }

  /*  IT IS RECOMMENDED THAT YOU USE THE safeApprove() FUNCTION INSTEAD OF approve() TO AVOID A TIMING ISSUES WITH THE ERC20 STANDARD.
      The approve function implements the standard to maintain backwards compatibility with ERC20.
      Read more about the race condition exploit of approve here https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   */
  function approve(address spender, uint256 value) public returns(bool success) {
    return _approve(spender, value);
  }

  // Use safeApprove() instead of approve() to avoid the race condition exploit which is a known security hole in the ERC20 standard
  function safeApprove(address spender, uint256 newApprovalValue, uint256 expectedApprovedValue, uint8 nonce) public
  returns(bool success) {
    require(expectedApprovedValue == _allowed[msg.sender][spender], "The expected approved amount does not match the actual approved amount");
    require(nonce == _approvalNonces[msg.sender][spender], "The nonce does not match the current transfer approval nonce");
    return _approve(spender, newApprovalValue);
  }

  // gets the current allowed transfers for a sender and receiver along with the spender's nonce
  function allowanceAndNonce(address spender) external view returns(uint256 spenderAllowance, uint8 nonce) {
    uint256 _allowance = _allowed[msg.sender][spender];
    uint8 _nonce = _approvalNonces[msg.sender][spender];
    return (_allowance, _nonce);
  }

  function transferFrom(address from, address to, uint256 value) public returns(bool success) {
    enforceTransferRestrictions(from, to, value);
    require(value <= _allowed[from][to], "The approved allowance is lower than the transfer amount");
    _allowed[from][msg.sender] = sub(_allowed[from][msg.sender], value);
    _transfer(from, to, value);
    return true;
  }

  /********** INTERNAL FUNCTIONS **********/

  function _approve(address spender, uint256 value) internal returns(bool success) {
    // use a nonce to enforce expected approval amounts for the approve and safeApprove functions
    _approvalNonces[msg.sender][spender]++; // intentional allowance for an overflow
    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  // if you call this function call forceRestriction before it
  function _transfer(address from, address to, uint256 value) internal {
    require(value <= _balances[from], "Insufficent tokens");
    _balances[from] = sub(_balances[from], value);
    _balances[to] = add(_balances[to], value);
    emit Transfer(from, to, value);
  }

  /********** SAFE MATH **********/
  function sub(uint256 a, uint256 b) internal pure returns(uint256 result) {
    require(b <= a, "Underflow error");
    uint256 c = a - b;
    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns(uint256 result) {
    uint256 c = a + b;
    require(c >= a, "Overflow error");
    return c;
  }
}
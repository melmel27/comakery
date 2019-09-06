pragma solidity ^0.5.8;

import "./TransferRules.sol";

contract ERC1404 {
  string public symbol;
  string public name;
  uint8 public decimals;
  uint256 public totalSupply;
  address public contractOwner;
  TransferRules public transferRules;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowed;
  mapping(address => mapping(address => uint8)) private _approvalNonces;

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
    
    transferRules = new TransferRules();
    symbol = _symbol;
    name = _name;
    decimals = _decimals;

    contractOwner = _contractOwner;

    _balances[_tokenReserveAdmin] = _totalSupply;
    totalSupply = _balances[_tokenReserveAdmin];
  }

  function enforceTransferRestrictions(address from, address to, uint256 value) public view {
    uint8 restrictionCode = transferRules.detectTransferRestriction(from, to, value);
    require(restrictionCode == transferRules.SUCCESS(), transferRules.messageForTransferRestriction(restrictionCode));
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
pragma solidity ^ 0.5 .0;


contract ERC1404 {
  string public symbol;
  string public name;
  uint8 public decimals;
  uint256 public totalSupply;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowed;
  mapping(address => mapping(address => uint8)) private _approvalNonces;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);


  constructor(address _initialTokenHolder, string memory _symbol) public {
    require(_initialTokenHolder != address(0), "Token holder address cannot be 0x0");
    
    symbol = _symbol;
    name = "foo";
    decimals = 18;
    totalSupply = 1e27;

    _balances[_initialTokenHolder] = totalSupply;
  }

  modifier validAddress(address _address) {
    require(_address != address(0), "Error 0x0 is an invalid address");
    _;
  }

  function balanceOf(address owner) public view returns(uint256 balance) {
    return _balances[owner];
  }

  function allowance(address owner, address spender) public view returns(uint256 remaining) {
    return _allowed[owner][spender];
  }

  function transfer(address to, uint256 value) public returns(bool success) {
    privateTransfer(msg.sender, to, value);
    return true;
  }

  /**
   * IT IS RECOMMENDED THAT YOU USE THE safeApprove() FUNCTION INSTEAD OF approve() TO AVOID A TIMING ISSUES WITH THE ERC20 STANDARD.
   * The approve function implements the standard to maintain backwards compatibility with ERC20.
   * Read more about the race condition exploit of approve here https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   */
  function approve(address spender, uint256 value) public validAddress(spender) returns(bool success) {
    return privateApprove(spender, value);
  }

  // Use safeApprove() instead of approve() to avoid the race condition exploit which is a known security hole in the ERC20 standard
  function safeApprove(address spender, uint256 newApprovalValue, uint256 expectedApprovedValue, uint8 nonce) public
  validAddress(spender)
  returns(bool success) {
    require(expectedApprovedValue == _allowed[msg.sender][spender], "The expected approved amount does not match the actual approved amount");
    require(nonce == _approvalNonces[msg.sender][spender], "The nonce does not match the current transfer approval nonce");
    return privateApprove(spender, newApprovalValue);
  }

  // fetch the current allowed transfers for a sender and receiver along with the spender's nonce
  function fetchPreApproval(address spender) external view returns(uint256 spenderAllowance, uint8 nonce) {
    uint256 _allowance = _allowed[msg.sender][spender];
    uint8 _nonce = _approvalNonces[msg.sender][spender];
    return (_allowance, _nonce);
  }

  // use a nonce to enfore expected approval amounts for the approve and safeApprove functions
  function privateApprove(address spender, uint256 value) internal returns(bool success) {
    // intentional allowance for an overflow
    _approvalNonces[msg.sender][spender]++;
    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public returns(bool success) {
    require(value <= _allowed[from][to], "The approved allowance is lower than the transfer amount");
    _allowed[from][msg.sender] = sub(_allowed[from][msg.sender], value);
    privateTransfer(from, to, value);
    return true;
  }

  function privateTransfer(address from, address to, uint256 value) internal validAddress(to) {
    require(value <= _balances[to], "Insufficent tokens");
    require(to != address(this), "To address cannot be this contract");
    _balances[from] = sub(_balances[from], value);
    _balances[to] = add(_balances[to], value);
    emit Transfer(from, to, value);
  }

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
pragma solidity ^ 0.5 .8;

import "./ITransferRules.sol";
import "./TransferRules.sol";
import "@openzeppelin/contracts/access/Roles.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract RestrictedToken {
  using SafeMath for uint256;

  string public symbol;
  string public name;
  uint8 public decimals;
  uint256 public totalSupply;
  ITransferRules public transferRules;

  using Roles for Roles.Role;
  Roles.Role private _contractAdmins;
  Roles.Role private _transferAdmins;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowed;
  mapping(address => mapping(address => uint8)) private _approvalNonces;  

  // transfer restriction storage
  uint256 public constant MAX_UINT = ((2 ** 255 - 1) * 2) + 1; // get max uint256 without overflow
  mapping(address => uint256) public maxBalances;
  mapping(address => uint256) public timeLock; // unix timestamp to lock funds until
  mapping(address => uint256) public transferGroups; // restricted groups like Reg S, Reg D and Reg CF
  mapping(uint256 => mapping(uint256 => uint256)) private _allowGroupTransfers; // approve transfers between groups: from => to => TimeLockUntil
  mapping(address => bool) public frozenAddresses;
  bool public isPaused = false;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event RoleChange(address indexed grantor, address indexed grantee, string role, bool indexed status);
  event MaxBalanceSet(address indexed admin, address indexed account, uint256 indexed value);
  event TimeLockSet(address indexed admin, address indexed account, uint256 indexed value);

  constructor(
    address _transferRules,
    address _contractAdmin,
    address _tokenReserveAdmin,
    string memory _symbol,
    string memory _name,
    uint8 _decimals,
    uint256 _totalSupply
  ) public {

    require(_contractAdmin != address(0), "Token owner address cannot be 0x0");

    // transfer rules can be swapped out
    // the storage stays in the ERC20
    transferRules = ITransferRules(_transferRules);
    symbol = _symbol;
    name = _name;
    decimals = _decimals;

    _contractAdmins.add(_contractAdmin);

    _balances[_tokenReserveAdmin] = _totalSupply;
    totalSupply = _balances[_tokenReserveAdmin];
  }

  modifier onlyContractAdmin() {
    require(_contractAdmins.has(msg.sender), "DOES NOT HAVE CONTRACT OWNER ROLE");
    _;
  }

   modifier onlyTransferAdmin() {
    require(_transferAdmins.has(msg.sender), "DOES NOT HAVE TRANSFER ADMIN ROLE");
    _;
  }

  modifier onlyTransferAdminOrContractAdmin() {
    require((_contractAdmins.has(msg.sender) || _transferAdmins.has(msg.sender)), 
    "DOES NOT HAVE TRANSFER ADMIN OR CONTRACT ADMIN ROLE");
    _;
  }

  function grantTransferAdmin(address _account) onlyContractAdmin public {
    _transferAdmins.add(_account);
    emit RoleChange(msg.sender, _account, "TransferAdmin", true);
  }

  function revokeTransferAdmin(address _account) onlyContractAdmin public {
    _transferAdmins.remove(_account);
    emit RoleChange(msg.sender, _account, "TransferAdmin", false);
  }

    function grantContractAdmin(address _account) onlyContractAdmin public {
    _contractAdmins.add(_account);
    emit RoleChange(msg.sender, _account, "ContractAdmin", true);
  }

  function revokeContractAdmin(address _account) onlyContractAdmin public {
    _contractAdmins.remove(_account);
    emit RoleChange(msg.sender, _account, "ContractAdmin", false);
  }

  function enforceTransferRestrictions(address from, address to, uint256 value) public view {
    uint8 restrictionCode = detectTransferRestriction(from, to, value);
    require(transferRules.checkSuccess(restrictionCode), transferRules.messageForTransferRestriction(restrictionCode));
  }

  function detectTransferRestriction(address from, address to, uint256 value) public view returns(uint8) {
    return transferRules.detectTransferRestriction(address(this), from, to, value);
  }

  function messageForTransferRestriction(uint8 restrictionCode) public view returns(string memory) {
    return transferRules.messageForTransferRestriction(restrictionCode);
  }

  function setMaxBalance(address _account, uint256 _updatedValue) public onlyTransferAdmin {
    maxBalances[_account] = _updatedValue;
    emit MaxBalanceSet(msg.sender, _account, _updatedValue);
  }

  function getMaxBalance(address _account) public view returns(uint256) {
    return maxBalances[_account];
  }

  function setTimeLock(address _account, uint256 _timestamp) public onlyTransferAdmin {
    timeLock[_account] = _timestamp;
    emit TimeLockSet(msg.sender, _account, _timestamp);
  }

  function removeTimeLock(address _account) public onlyTransferAdmin {
    timeLock[_account] = 0;
  }

  function getTimeLock(address _account) public view returns(uint256) {
    return timeLock[_account];
  }

  function setGroup(address addr, uint256 groupID) public onlyTransferAdmin {
    transferGroups[addr] = groupID;
  }

  function getTransferGroup(address addr) public view returns(uint256 groupID) {
    return transferGroups[addr];
  }

  function setAccountPermissions(address addr, uint256 groupID, uint256 timeLockUntil, uint256 maxTokens, bool status) public onlyTransferAdmin {
    setGroup(addr, groupID);
    setTimeLock(addr, timeLockUntil);
    setMaxBalance(addr, maxTokens);
    freeze(addr, status);
  }

  // TODO: if transferAfter = 0 no transfer; update README
  // TODO: if transferAfter = 1 any transfer works; update README
  function setAllowGroupTransfer(uint256 groupA, uint256 groupB, uint256 transferAfter) public onlyTransferAdmin {
    _allowGroupTransfers[groupA][groupB] = transferAfter;
  }

  function getAllowGroupTransfer(uint256 from, uint256 to, uint256 timestamp) public view returns(bool) {
    if (_allowGroupTransfers[from][to] == 0) return false;
    return _allowGroupTransfers[from][to] < timestamp;
  }

  function getAllowTransfer(address from, address to, uint256 atTimestamp) public view returns(bool) {
    getAllowGroupTransfer(getTransferGroup(from), getTransferGroup(to), atTimestamp);
  }

  function setTransferRules(ITransferRules newTransferRules) public onlyContractAdmin {
    transferRules = newTransferRules;
  }

  // note the transfer time default is 0 for transfers between all addresses
  // a transfer time of 0 is treated as not allowed
  function getAllowTransferTime(address from, address to) public view returns(uint timestamp) {
    return _allowGroupTransfers[transferGroups[from]][transferGroups[to]];
  }

  function freeze(address addr, bool status) public onlyTransferAdminOrContractAdmin {
    frozenAddresses[addr] = status;
  }

  function frozen(address addr) public view returns(bool) {
    return frozenAddresses[addr];
  }

  function burnFrom(address from, uint256 value) public onlyContractAdmin {
    require(value <= _balances[from], "Insufficent tokens to burn");
    _balances[from] = _balances[from].sub(value);
    totalSupply = totalSupply.sub(value);
  }

  function mint(address to, uint256 value) public onlyContractAdmin  {
    _balances[to] = _balances[to].add(value);
    totalSupply = totalSupply.add(value);
  }

  function pause() public onlyContractAdmin() {
    isPaused = true;
  }

  function unpause() public onlyContractAdmin() {
    isPaused = false;
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
    _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
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
    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
  }
}
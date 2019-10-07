pragma solidity 0.5.12;

import "./ITransferRules.sol";
import "@openzeppelin/contracts/access/Roles.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Restricted Token
/// @author CoMakery, Inc.
/// @notice An ERC-20 token with ERC-1404 transfer restrictions for managing security tokens, etc.
contract RestrictedToken is IERC20 {
  using SafeMath for uint256;

  string public symbol;
  string public name;
  uint8 public decimals;
  uint256 private internalTotalSupply;
  ITransferRules public transferRules;

  using Roles for Roles.Role;
  Roles.Role private contractAdmins;
  Roles.Role private transferAdmins;

  mapping(address => uint256) private balances;
  uint256 public maxTotalSupply;
  uint256 public contractAdminCount;

  // transfer restriction storage
  mapping(address => mapping(address => uint256)) private allowed;
  mapping(address => mapping(address => uint8)) private approvalNonces;
  uint256 public constant MAX_UINT = ((2 ** 255 - 1) * 2) + 1; // get max uint256 without overflow
  mapping(address => uint256) public maxBalances;
  mapping(address => uint256) public lockUntil; // unix timestamp to lock funds until
  mapping(address => uint256) public transferGroups; // restricted groups like Reg S, Reg D and Reg CF
  mapping(uint256 => mapping(uint256 => uint256)) private allowGroupTransfers; // approve transfers between groups: from => to => TimeLockUntil
  mapping(address => bool) public frozenAddresses;
  bool public isPaused = false;

  event RoleChange(address indexed grantor, address indexed grantee, string role, bool indexed status);
  event AddressMaxBalance(address indexed admin, address indexed addr, uint256 indexed value);
  event AddressTimeLock(address indexed admin, address indexed addr, uint256 indexed value);
  event AddressTransferGroup(address indexed admin, address indexed addr, uint256 indexed value);
  event AddressFrozen(address indexed admin, address indexed addr, bool indexed status);
  event AllowGroupTransfer(address indexed admin, uint256 indexed fromGroup, uint256 indexed toGroup, uint256 lockedUntil);

  event Mint(address indexed admin, address indexed addr, uint256 indexed value);
  event Burn(address indexed admin, address indexed addr, uint256 indexed value);
  event Pause(address admin, bool status);
  event Upgrade(address admin, address oldRules, address newRules);

  constructor(
    address _transferRules,
    address _contractAdmin,
    address _tokenReserveAdmin,
    string memory _symbol,
    string memory _name,
    uint8 _decimals,
    uint256 _totalSupply,
    uint256 _maxTotalSupply
  ) public {
    require(_transferRules != address(0), "Transfer rules address cannot be 0x0");
    require(_contractAdmin != address(0), "Token owner address cannot be 0x0");
    require(_tokenReserveAdmin != address(0), "Token reserve admin address cannot be 0x0");

    // Transfer rules can be swapped out for a new contract inheriting from the ITransferRules interface
    // The storage stays in this contract and functions as an eternal storage.
    transferRules = ITransferRules(_transferRules);
    symbol = _symbol;
    name = _name;
    decimals = _decimals;
    maxTotalSupply = _maxTotalSupply;

    contractAdmins.add(_contractAdmin);
    contractAdminCount = 1;

    balances[_tokenReserveAdmin] = _totalSupply;
    internalTotalSupply = balances[_tokenReserveAdmin];
  }

  modifier onlyContractAdmin() {
    require(contractAdmins.has(msg.sender), "DOES NOT HAVE CONTRACT OWNER ROLE");
    _;
  }

   modifier onlyTransferAdmin() {
    require(transferAdmins.has(msg.sender), "DOES NOT HAVE TRANSFER ADMIN ROLE");
    _;
  }

  modifier onlyTransferAdminOrContractAdmin() {
    require((contractAdmins.has(msg.sender) || transferAdmins.has(msg.sender)),
    "DOES NOT HAVE TRANSFER ADMIN OR CONTRACT ADMIN ROLE");
    _;
  }

  modifier validAddress(address addr) {
    require(addr != address(0), "Address cannot be 0x0");
    _;
  }

  /// @notice Authorizes an address holder to write transfer restriction rules
  /// @param addr The address to grant transfer admin rights to
  function grantTransferAdmin(address addr) external validAddress(addr) onlyContractAdmin {
    transferAdmins.add(addr);
    emit RoleChange(msg.sender, addr, "TransferAdmin", true);
  }

  /// @notice Revokes authorization to write transfer restriction rules
  /// @param addr The address to grant transfer admin rights to
  function revokeTransferAdmin(address addr) external validAddress(addr) onlyContractAdmin  {
    transferAdmins.remove(addr);
    emit RoleChange(msg.sender, addr, "TransferAdmin", false);
  }
  
  /// @notice Authorizes an address holder to be a contract admin. Contract admins grant privalages to accounts.
  /// Contract admins can mint/burn tokens and freeze accounts.
  /// @param addr The address to grant transfer admin rights to
  function grantContractAdmin(address addr) external validAddress(addr) onlyContractAdmin {
    contractAdmins.add(addr);
    contractAdminCount = contractAdminCount.add(1);
    emit RoleChange(msg.sender, addr, "ContractAdmin", true);
  }

  /// @notice Revokes authorization as a contract admin.
  /// The contract requires there is at least 1 Contract Admin to avoid locking the Contract Admin functionality.
  /// @param addr The address to remove contract admin rights from
  function revokeContractAdmin(address addr) external validAddress(addr) onlyContractAdmin {
    require(contractAdminCount > 1, "Must have at least one contract admin");
    contractAdmins.remove(addr);
    contractAdminCount = contractAdminCount.sub(1);
    emit RoleChange(msg.sender, addr, "ContractAdmin", false);
  }

  /// @notice Enforces transfer restrictions managed using the ERC-1404 standard functions.
  /// The rules to enforce are managed by the TransferRules contract - which is upgradable.
  /// @param from The address the tokens are transferred from
  /// @param to The address the tokens would be transferred to
  /// @param value the quantity of tokens to be transferred
  function enforceTransferRestrictions(address from, address to, uint256 value) public view {
    uint8 restrictionCode = detectTransferRestriction(from, to, value);
    require(transferRules.checkSuccess(restrictionCode), messageForTransferRestriction(restrictionCode));
  }

  /// @notice Calls the TransferRules detectTransferRetriction function to determine if tokens can be transferred.
  /// detectTransferRestriction returns a status code.
  /// @param from The address the tokens are transferred from
  /// @param to The address the tokens would be transferred to
  /// @param value The quantity of tokens to be transferred
  function detectTransferRestriction(address from, address to, uint256 value) public view returns(uint8) {
    return transferRules.detectTransferRestriction(address(this), from, to, value);
  }

  /// @notice Calls TransferRules to lookup a human readable error message that goes with an error code.
  /// @param restrictionCode is an error code to lookup an error code for
  function messageForTransferRestriction(uint8 restrictionCode) public view returns(string memory) {
    return transferRules.messageForTransferRestriction(restrictionCode);
  }

  /// @notice Sets the maximum number of tokens an address will be allowed to hold.
  /// Addresses can hold 0 tokens by default.
  /// @param addr The address to restrict
  /// @param updatedValue the maximum number of tokens the address can hold
  function setMaxBalance(address addr, uint256 updatedValue) public validAddress(addr) onlyTransferAdmin {
    maxBalances[addr] = updatedValue;
    emit AddressMaxBalance(msg.sender, addr, updatedValue);
  }

  /// @notice Gets the maximum number of tokens an address is allowed to hold
  /// @param addr The address to check restrictions for
  function getMaxBalance(address addr) external view returns(uint256) {
    return maxBalances[addr];
  }

  /// @notice Lock tokens in the address from being transfered until the specified time
  /// @param addr The address to restrict
  /// @param timestamp The time the tokens will be locked until as a Unix timetsamp.
  /// Unix timestamp is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function setLockUntil(address addr, uint256 timestamp) public validAddress(addr)  onlyTransferAdmin {
    lockUntil[addr] = timestamp;
    emit AddressTimeLock(msg.sender, addr, timestamp);
  }
  /// @notice A convenience method to remove an addresses timelock. It sets the lock date to 0 which corresponds to the
  /// earliest possible timestaamp in the past 00:00:00 UTC on 1 January 1970.
  /// @param addr The address to remove the timelock for.
  function removeLockUntil(address addr) external validAddress(addr) onlyTransferAdmin {
    lockUntil[addr] = 0;
    emit AddressTimeLock(msg.sender, addr, 0);
  }

  /// @notice Check when the address will be locked for transfers until
  /// @param addr The address to check
  /// @return timestamp The time the address will be locked until.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function getLockUntil(address addr) external view returns(uint256 timestamp) {
    return lockUntil[addr];
  }

  /// @notice Set the one group that the address belongs to, such as a US Reg CF investor group.
  /// @param addr The address to set the group for.
  /// @param groupID The uint256 numeric ID of the group.
  function setTransferGroup(address addr, uint256 groupID) public validAddress(addr) onlyTransferAdmin {
    transferGroups[addr] = groupID;
    emit AddressTransferGroup(msg.sender, addr, groupID);
  }

  /// @notice Gets the transfer group the address belongs to. The default group is 0.
  /// @param addr The address to check.
  /// @return groupID The group id of the address.
  function getTransferGroup(address addr) external view returns(uint256 groupID) {
    return transferGroups[addr];
  }

  /// @notice Freezes or unfreezes an address.
  /// Tokens in a frozen address cannot be transferred from until the address is unfrozen.
  /// @param addr The address to be frozen.
  /// @param status The frozenAddress status of the address. True means frozen false means not frozen.
  function freeze(address addr, bool status) public validAddress(addr)  onlyTransferAdminOrContractAdmin {
    frozenAddresses[addr] = status;
    emit AddressFrozen(msg.sender, addr, status);
  }

  /// @notice Checks the status of an address to see if its frozen
  /// @param addr The address to check
  /// @return status Returns true if the address is frozen and false if its not frozen.
  function getFrozenStatus(address addr) external view returns(bool status) {
    return frozenAddresses[addr];
  }

  /// @notice A convenience method for updating the transfer group, lock until, max balance, and freeze status.
  /// The convenience method also helps to reduce gas costs.
  /// @param addr The address to set permissions for.
  /// @param groupID The ID of the address
  /// @param timeLockUntil The unix timestamp that the address should be locked until. Use 0 if it's not locked.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  /// @param maxBalance Is the maximum number of tokens the account can hold.
  /// @param status The frozenAddress status of the address. True means frozen false means not frozen.
  function setAddressPermissions(address addr, uint256 groupID, uint256 timeLockUntil,
    uint256 maxBalance, bool status) public validAddress(addr) onlyTransferAdmin {
    setTransferGroup(addr, groupID);
    setLockUntil(addr, timeLockUntil);
    setMaxBalance(addr, maxBalance);
    freeze(addr, status);
  }

  /// @notice Sets an allowed transfer from a group to another group beginning at a specific time.
  /// There is only one definitive rule per from and to group.
  /// @param from The group the transfer is coming from.
  /// @param to The group the transfer is going to.
  /// @param lockedUntil The unix timestamp that the transfer is locked until. 0 is a special number. 0 means the transfer is not allowed.
  /// This is because in the smart contract mapping all pairs are implicitly defined with a default lockedUntil value of 0.
  /// But no transfers should be authorized until explicitly allowed. Thus 0 must mean no transfer is allwed.
  function setAllowGroupTransfer(uint256 from, uint256 to, uint256 lockedUntil) external onlyTransferAdmin {
    allowGroupTransfers[from][to] = lockedUntil;
    emit AllowGroupTransfer(msg.sender, from, to, lockedUntil);
  }

  /// @notice Checks to see when a transfer between two addresses would be allowed.
  /// @param from The address the transfer is coming from
  /// @param to The address the transfer is going to
  /// @return timestamp The Unix timestamp of the time the transfer would be allowed. A 0 means never.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function getAllowTransferTime(address from, address to) external view returns(uint timestamp) {
    return allowGroupTransfers[transferGroups[from]][transferGroups[to]];
  }

  /// @notice Checks to see when a transfer between two groups would be allowed.
  /// @param from The group id the transfer is coming from
  /// @param to The group id the transfer is going to
  /// @return timestamp The Unix timestamp of the time the transfer would be allowed. A 0 means never.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function getAllowGroupTransferTime(uint from, uint to) external view returns(uint timestamp) {
    return allowGroupTransfers[from][to];
  }

  /// @notice Destroys tokens and removes them from the total supply. Can only be called by an address with a Contract Admin role.
  /// @param from The address to destroy the tokens from.
  /// @param value The number of tokens to destroy from the address.
  function burnFrom(address from, uint256 value) external validAddress(from) onlyContractAdmin {
    require(value <= balances[from], "Insufficent tokens to burn");
    balances[from] = balances[from].sub(value);
    internalTotalSupply = internalTotalSupply.sub(value);
    emit Burn(msg.sender, from, value);
  }

  /// @notice Allows the contract admin to create new tokens in a specified address.
  /// The total number of tokens cannot exceed the maxTotalSupply (the "Hard Cap").
  /// @param to The addres to mint tokens into.
  /// @param value The number of tokens to mint.
  function mint(address to, uint256 value) external validAddress(to) onlyContractAdmin  {
    require(internalTotalSupply.add(value) <= maxTotalSupply, "Cannot mint more than the max total supply");
    balances[to] = balances[to].add(value);
    internalTotalSupply = internalTotalSupply.add(value);
    emit Mint(msg.sender, to, value);
  }

  /// @notice Allows the contract admin to pause transfers.
  function pause() external onlyContractAdmin() {
    isPaused = true;
    emit Pause(msg.sender, true);
  }

  /// @notice Allows the contract admin to unpause transfers.
  function unpause() external onlyContractAdmin() {
    isPaused = false;
    emit Pause(msg.sender, false);
  }

  /// @notice Allows the contrac admin to upgrade the transfer rules.
  /// The upgraded transfer rules must implement the ITransferRules interface which conforms to the ERC-1404 token standard.
  /// @param newTransferRules The address of the deployed TransferRules contract.
  function upgradeTransferRules(ITransferRules newTransferRules) external onlyContractAdmin {
    require(address(newTransferRules) != address(0x0), "Address cannot be 0x0");
    address oldRules = address(transferRules);
    transferRules = newTransferRules;
    emit Upgrade(msg.sender, oldRules, address(newTransferRules));
  }

  /******* ERC20 FUNCTIONS ***********/

  function totalSupply() external view returns (uint256) {
    return internalTotalSupply;
  }

  function balanceOf(address owner) external view returns(uint256 balance) {
    return balances[owner];
  }

  function allowance(address owner, address spender) external view returns(uint256 remaining) {
    return allowed[owner][spender];
  }

  function transfer(address to, uint256 value) external validAddress(to) returns(bool success) {
    enforceTransferRestrictions(msg.sender, to, value);
    _transfer(msg.sender, to, value);
    return true;
  }

  /// @notice IT IS RECOMMENDED THAT YOU USE THE safeApprove() FUNCTION INSTEAD OF approve() TO AVOID A TIMING ISSUES WITH THE ERC20 STANDARD.
  /// The approve function implements the standard to maintain backwards compatibility with ERC20.
  /// Read more about the race condition exploit of approve here https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
  /// approve() always returns false so that users are always informed that they should employ safeApprove while not breaking ERC20 usage.
  /// @param spender The person to authorize to spend tokens on the approvers behalf.
  /// @param value The amount to authorize for the spender to spend.
  /// @return success Always returns false so as to indicate that safeApprove should be used instead.
  function approve(address spender, uint256 value) external validAddress(spender) returns(bool success) {
    _approve(spender, value);
    return false;
  }

  /// @notice Use safeApprove() instead of approve() to avoid the race condition exploit which is a known security hole in the ERC20 standard
  /// @param spender The person to authorize to spend.
  /// @param newApprovalValue The amount to approve.
  /// @param expectedApprovedValue The amount that the caller expects is currently approved.
  /// @param nonce The expected nonce value of the last approval.
  /// @return success Always returns true.
  function safeApprove(address spender, uint256 newApprovalValue,
    uint256 expectedApprovedValue, uint8 nonce) external validAddress(spender)
  returns(bool success) {
    require(expectedApprovedValue == allowed[msg.sender][spender],
      "The expected approved amount does not match the actual approved amount");
    require(nonce == approvalNonces[msg.sender][spender], "The nonce does not match the current transfer approval nonce");
    return _approve(spender, newApprovalValue);
  }

  /// @notice gets the current allowed transfers for a sender and receiver along with the spender's nonce
  /// @param spender The address of the spender.
  /// @return spenderAllowance The amount the spender is allowed to spend.
  /// @return nonce The nonce id to be passed into safeApprove for verifying that the current account approval is valid for the spender.
  function allowanceAndNonce(address spender) external view returns(uint256 spenderAllowance, uint8 nonce) {
    uint256 _allowance = allowed[msg.sender][spender];
    uint8 _nonce = approvalNonces[msg.sender][spender];
    return (_allowance, _nonce);
  }

  function transferFrom(address from, address to, uint256 value) external validAddress(from) validAddress(to) returns(bool success) {
    enforceTransferRestrictions(from, to, value);
    require(value <= allowed[from][to], "The approved allowance is lower than the transfer amount");
    allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  /********** INTERNAL FUNCTIONS **********/

  function _approve(address spender, uint256 value) internal returns(bool success) {
    // use a nonce to enforce expected approval amounts for the approve and safeApprove functions
    approvalNonces[msg.sender][spender]++; // intentional allowance for an overflow
    allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  // if you call this function call forceRestriction before it
  function _transfer(address from, address to, uint256 value) internal {
    require(value <= balances[from], "Insufficent tokens");
    balances[from] = balances[from].sub(value);
    balances[to] = balances[to].add(value);
    emit Transfer(from, to, value);
  }
}
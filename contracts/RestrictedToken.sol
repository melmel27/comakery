pragma solidity 0.5.12;

import "./ITransferRules.sol";
import "@openzeppelin/contracts/access/Roles.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Restricted Token
/// @author CoMakery, Inc.
/// @notice An ERC-20 token with ERC-1404 transfer restrictions for managing security tokens, etc.
contract RestrictedToken is ERC20 {
  using SafeMath for uint256;

  string public symbol;
  string public name;
  uint8 public decimals;
  ITransferRules public transferRules;

  using Roles for Roles.Role;
  Roles.Role private _contractAdmins;
  Roles.Role private _transferAdmins;

  uint256 public maxTotalSupply;
  uint256 public contractAdminCount;

  // transfer restriction "eternal storage" that can be used by future TransferRules contract upgrades
  uint256 public constant MAX_UINT256 = ((2 ** 255 - 1) * 2) + 1; // get max uint256 without overflow
  mapping(address => uint256) public maxBalances;
  mapping(address => uint256) public lockUntil; // unix timestamp to lock funds until
  mapping(address => uint256) public transferGroups; // restricted groups like Reg D Accredited US, Reg CF Unaccredited US and Reg S Foreign
  mapping(uint256 => mapping(uint256 => uint256)) private _allowGroupTransfers; // approve transfers between groups: from => to => TimeLockUntil
  mapping(address => bool) public frozenAddresses;
  bool public isPaused = false;

  event RoleChange(address indexed grantor, address indexed grantee, string role, bool indexed status);
  event AddressMaxBalance(address indexed admin, address indexed addr, uint256 indexed value);
  event AddressTimeLock(address indexed admin, address indexed addr, uint256 indexed value);
  event AddressTransferGroup(address indexed admin, address indexed addr, uint256 indexed value);
  event AddressFrozen(address indexed admin, address indexed addr, bool indexed status);
  event AllowGroupTransfer(address indexed admin, uint256 indexed fromGroup, uint256 indexed toGroup, uint256 lockedUntil);

  event Pause(address admin, bool status);
  event Upgrade(address admin, address oldRules, address newRules);

  constructor(
    address transferRules_,
    address contractAdmin_,
    address tokenReserveAdmin_,
    string memory symbol_,
    string memory name_,
    uint8 decimals_,
    uint256 totalSupply_,
    uint256 maxTotalSupply_
  ) public {
    require(transferRules_ != address(0), "Transfer rules address cannot be 0x0");
    require(contractAdmin_ != address(0), "Token owner address cannot be 0x0");
    require(tokenReserveAdmin_ != address(0), "Token reserve admin address cannot be 0x0");

    // Transfer rules can be swapped out for a new contract inheriting from the ITransferRules interface
    // The "eternal storage" for rule data stays in this RestrictedToken contract for use by TransferRules contract upgrades
    transferRules = ITransferRules(transferRules_);
    symbol = symbol_;
    name = name_;
    decimals = decimals_;
    maxTotalSupply = maxTotalSupply_;

    _contractAdmins.add(contractAdmin_);
    contractAdminCount = 1;

    _mint(tokenReserveAdmin_, totalSupply_);
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

  modifier validAddress(address addr) {
    require(addr != address(0), "Address cannot be 0x0");
    _;
  }

  /// @dev Authorizes an address holder to write transfer restriction rules
  /// @param addr The address to grant transfer admin rights to
  function grantTransferAdmin(address addr) external validAddress(addr) onlyContractAdmin {
    _transferAdmins.add(addr);
    emit RoleChange(msg.sender, addr, "TransferAdmin", true);
  }

  /// @dev Revokes authorization to write transfer restriction rules
  /// @param addr The address to grant transfer admin rights to
  function revokeTransferAdmin(address addr) external validAddress(addr) onlyContractAdmin  {
    _transferAdmins.remove(addr);
    emit RoleChange(msg.sender, addr, "TransferAdmin", false);
  }

  /// @dev Authorizes an address holder to be a contract admin. Contract admins grant privileges to accounts.
  /// Contract admins can mint/burn tokens and freeze accounts.
  /// @param addr The address to grant transfer admin rights to.
  function grantContractAdmin(address addr) external validAddress(addr) onlyContractAdmin {
    _contractAdmins.add(addr);
    contractAdminCount = contractAdminCount.add(1);
    emit RoleChange(msg.sender, addr, "ContractAdmin", true);
  }

  /// @dev Checks if an address is an authorized transfer admin.
  /// @param addr The address to check for transfer admin privileges.
  /// @return hasPermission returns true if the address has transfer admin permission false if not.
  function checkTransferAdmin(address addr) external view returns(bool hasPermission) {
    return _transferAdmins.has(addr);
  }

  /// @dev Revokes authorization as a contract admin.
  /// The contract requires there is at least 1 Contract Admin to avoid locking the Contract Admin functionality.
  /// @param addr The address to remove contract admin rights from
  function revokeContractAdmin(address addr) external validAddress(addr) onlyContractAdmin {
    require(contractAdminCount > 1, "Must have at least one contract admin");
    _contractAdmins.remove(addr);
    contractAdminCount = contractAdminCount.sub(1);
    emit RoleChange(msg.sender, addr, "ContractAdmin", false);
  }

  /// @dev Enforces transfer restrictions managed using the ERC-1404 standard functions.
  /// The TransferRules contract defines what the rules are. The data inputs to those rules remains in the RestrictedToken contract.
  /// TransferRules is a separate contract so its logic can be upgraded.
  /// @param from The address the tokens are transferred from
  /// @param to The address the tokens would be transferred to
  /// @param value the quantity of tokens to be transferred
  function enforceTransferRestrictions(address from, address to, uint256 value) public view {
    uint8 restrictionCode = detectTransferRestriction(from, to, value);
    require(transferRules.checkSuccess(restrictionCode), messageForTransferRestriction(restrictionCode));
  }

  /// @dev Calls the TransferRules detectTransferRetriction function to determine if tokens can be transferred.
  /// detectTransferRestriction returns a status code.
  /// @param from The address the tokens are transferred from
  /// @param to The address the tokens would be transferred to
  /// @param value The quantity of tokens to be transferred
  function detectTransferRestriction(address from, address to, uint256 value) public view returns(uint8) {
    return transferRules.detectTransferRestriction(address(this), from, to, value);
  }

  /// @dev Calls TransferRules to lookup a human readable error message that goes with an error code.
  /// @param restrictionCode is an error code to lookup an error code for
  function messageForTransferRestriction(uint8 restrictionCode) public view returns(string memory) {
    return transferRules.messageForTransferRestriction(restrictionCode);
  }

  /// @dev Sets the maximum number of tokens an address will be allowed to hold.
  /// Addresses can hold 0 tokens by default.
  /// @param addr The address to restrict
  /// @param updatedValue the maximum number of tokens the address can hold
  function setMaxBalance(address addr, uint256 updatedValue) public validAddress(addr) onlyTransferAdmin {
    maxBalances[addr] = updatedValue;
    emit AddressMaxBalance(msg.sender, addr, updatedValue);
  }

  /// @dev Gets the maximum number of tokens an address is allowed to hold
  /// @param addr The address to check restrictions for
  function getMaxBalance(address addr) external view returns(uint256) {
    return maxBalances[addr];
  }

  /// @dev Lock tokens in the address from being transfered until the specified time
  /// @param addr The address to restrict
  /// @param timestamp The time the tokens will be locked until as a Unix timetsamp.
  /// Unix timestamp is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function setLockUntil(address addr, uint256 timestamp) public validAddress(addr)  onlyTransferAdmin {
    lockUntil[addr] = timestamp;
    emit AddressTimeLock(msg.sender, addr, timestamp);
  }
  /// @dev A convenience method to remove an addresses timelock. It sets the lock date to 0 which corresponds to the
  /// earliest possible timestamp in the past 00:00:00 UTC on 1 January 1970.
  /// @param addr The address to remove the timelock for.
  function removeLockUntil(address addr) external validAddress(addr) onlyTransferAdmin {
    lockUntil[addr] = 0;
    emit AddressTimeLock(msg.sender, addr, 0);
  }

  /// @dev Check when the address will be locked for transfers until
  /// @param addr The address to check
  /// @return timestamp The time the address will be locked until.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function getLockUntil(address addr) external view returns(uint256 timestamp) {
    return lockUntil[addr];
  }

  /// @dev Set the one group that the address belongs to, such as a US Reg CF investor group.
  /// @param addr The address to set the group for.
  /// @param groupID The uint256 numeric ID of the group.
  function setTransferGroup(address addr, uint256 groupID) public validAddress(addr) onlyTransferAdmin {
    transferGroups[addr] = groupID;
    emit AddressTransferGroup(msg.sender, addr, groupID);
  }

  /// @dev Gets the transfer group the address belongs to. The default group is 0.
  /// @param addr The address to check.
  /// @return groupID The group id of the address.
  function getTransferGroup(address addr) external view returns(uint256 groupID) {
    return transferGroups[addr];
  }

  /// @dev Freezes or unfreezes an address.
  /// Tokens in a frozen address cannot be transferred from until the address is unfrozen.
  /// @param addr The address to be frozen.
  /// @param status The frozenAddress status of the address. True means frozen false means not frozen.
  function freeze(address addr, bool status) public validAddress(addr)  onlyTransferAdminOrContractAdmin {
    frozenAddresses[addr] = status;
    emit AddressFrozen(msg.sender, addr, status);
  }

  /// @dev Checks the status of an address to see if its frozen
  /// @param addr The address to check
  /// @return status Returns true if the address is frozen and false if its not frozen.
  function getFrozenStatus(address addr) external view returns(bool status) {
    return frozenAddresses[addr];
  }

  /// @dev A convenience method for updating the transfer group, lock until, max balance, and freeze status.
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

  /// @dev Sets an allowed transfer from a group to another group beginning at a specific time.
  /// There is only one definitive rule per from and to group.
  /// @param from The group the transfer is coming from.
  /// @param to The group the transfer is going to.
  /// @param lockedUntil The unix timestamp that the transfer is locked until. 0 is a special number. 0 means the transfer is not allowed.
  /// This is because in the smart contract mapping all pairs are implicitly defined with a default lockedUntil value of 0.
  /// But no transfers should be authorized until explicitly allowed. Thus 0 must mean no transfer is allowed.
  function setAllowGroupTransfer(uint256 from, uint256 to, uint256 lockedUntil) external onlyTransferAdmin {
    _allowGroupTransfers[from][to] = lockedUntil;
    emit AllowGroupTransfer(msg.sender, from, to, lockedUntil);
  }

  /// @dev Checks to see when a transfer between two addresses would be allowed.
  /// @param from The address the transfer is coming from
  /// @param to The address the transfer is going to
  /// @return timestamp The Unix timestamp of the time the transfer would be allowed. A 0 means never.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function getAllowTransferTime(address from, address to) external view returns(uint timestamp) {
    return _allowGroupTransfers[transferGroups[from]][transferGroups[to]];
  }

  /// @dev Checks to see when a transfer between two groups would be allowed.
  /// @param from The group id the transfer is coming from
  /// @param to The group id the transfer is going to
  /// @return timestamp The Unix timestamp of the time the transfer would be allowed. A 0 means never.
  /// The format is the number of seconds since the Unix epoch of 00:00:00 UTC on 1 January 1970.
  function getAllowGroupTransferTime(uint from, uint to) external view returns(uint timestamp) {
    return _allowGroupTransfers[from][to];
  }

  /// @dev Destroys tokens and removes them from the total supply. Can only be called by an address with a Contract Admin role.
  /// @param from The address to destroy the tokens from.
  /// @param value The number of tokens to destroy from the address.
  function burn(address from, uint256 value) external validAddress(from) onlyContractAdmin {
    require(value <= balanceOf(from), "Insufficent tokens to burn");
    _burn(from, value);
  }

  /// @dev Allows the contract admin to create new tokens in a specified address.
  /// The total number of tokens cannot exceed the maxTotalSupply (the "Hard Cap").
  /// @param to The addres to mint tokens into.
  /// @param value The number of tokens to mint.
  function mint(address to, uint256 value) external validAddress(to) onlyContractAdmin  {
    require(SafeMath.add(totalSupply(), value) <= maxTotalSupply, "Cannot mint more than the max total supply");
    _mint(to, value);
  }

  /// @dev Allows the contract admin to pause transfers.
  function pause() external onlyContractAdmin() {
    isPaused = true;
    emit Pause(msg.sender, true);
  }

  /// @dev Allows the contract admin to unpause transfers.
  function unpause() external onlyContractAdmin() {
    isPaused = false;
    emit Pause(msg.sender, false);
  }

  /// @dev Allows the contrac admin to upgrade the transfer rules.
  /// The upgraded transfer rules must implement the ITransferRules interface which conforms to the ERC-1404 token standard.
  /// @param newTransferRules The address of the deployed TransferRules contract.
  function upgradeTransferRules(ITransferRules newTransferRules) external onlyContractAdmin {
    require(address(newTransferRules) != address(0x0), "Address cannot be 0x0");
    address oldRules = address(transferRules);
    transferRules = newTransferRules;
    emit Upgrade(msg.sender, oldRules, address(newTransferRules));
  }

  function transfer(address to, uint256 value) public validAddress(to) returns(bool success) {
    require(value <= balanceOf(msg.sender), "Insufficent tokens");
    enforceTransferRestrictions(msg.sender, to, value);
    super.transfer(to, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public validAddress(from) validAddress(to) returns(bool success) {
    require(value <= allowance(from, to), "The approved allowance is lower than the transfer amount");
    require(value <= balanceOf(from), "Insufficent tokens");
    enforceTransferRestrictions(from, to, value);
    super.transferFrom(from, to, value);
    return true;
  }

  function safeApprove(address spender, uint256 value) public {
    // safeApprove should only be called when setting an initial allowance,
    // or when resetting it to zero. To increase and decrease it, use
    // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
    require((value == 0) || (allowance(address(msg.sender), spender) == 0),
        "Cannot approve from non-zero to non-zero allowance"
    );
    approve(spender, value);
  }
}
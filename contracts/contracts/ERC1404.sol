pragma solidity ^0.5.0;


contract ERC1404 {
  string public symbol;
  
  constructor(string memory _symbol) public {
    symbol = _symbol;
  }
}

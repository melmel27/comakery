pragma solidity 0.5.12;

contract ITransferRules {
    /// @notice Detects if a transfer will be reverted and if so returns an appropriate reference code
    /// @param from Sending address
    /// @param to Receiving address
    /// @param value Amount of tokens being transferred
    /// @return Code by which to reference message for rejection reasoning

    // TODO: require that address token is of tyle RestrictedToken instead?
    function detectTransferRestriction(
        address token,
        address from,
        address to,
        uint256 value
    ) public view returns (uint8);

    /// @notice Returns a human-readable message for a given restriction code
    /// @param restrictionCode Identifier for looking up a message
    /// @return Text showing the restriction's reasoning
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        view
        returns (string memory);

    function checkSuccess(uint8 restrictionCode) public view returns (bool);
}

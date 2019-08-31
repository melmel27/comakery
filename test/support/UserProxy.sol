import "../../contracts/ERC1404.sol";
contract UserProxy {
    ERC1404 public token;
    constructor(ERC1404 _token) public {
        token = _token;
    }

    function transfer(address to, uint amount) public returns(bool success) {
        return transfer(to, amount);
    }

    function setApprovedReceiver(address _account, bool _updatedValue) public {
        token.setApprovedReceiver(_account, _updatedValue);
    }
}
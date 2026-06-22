pragma gosh-solidity >=0.76.1;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

contract Vault {
    address _owner;
    TvmCell _encryptedData;
    uint32  _version;
    uint64  _updatedAt;

    event VaultUpdated(uint32 version, uint64 timestamp);
    event OwnershipTransferred(address indexed prevOwner, address indexed newOwner);

    constructor(address owner, uint64 value) {
        gosh.cnvrtshellq(value);
        require(owner != address(0), 101);
        tvm.accept();
        _owner = owner;
        _version = 0;
        _updatedAt = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, 401);
        tvm.accept();
        _;
    }

    function update(TvmCell data) external onlyOwner {
        _encryptedData = data;
        _version++;
        _updatedAt = block.timestamp;
        emit VaultUpdated(_version, _updatedAt);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), 402);
        address prev = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function getVault() external view returns (
        TvmCell encryptedData,
        uint32  version,
        uint64  updatedAt
    ) {
        return (_encryptedData, _version, _updatedAt);
    }

    function getOwner() external view returns (address) {
        return _owner;
    }

    function getVersion() external pure returns (string) {
        return "1.0.0";
    }

    receive() external {
    }
}

// SPDX-License-Identifier: MIT

// File: contracts/Context.sol
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
pragma solidity >=0.8.2 <0.9.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: contracts/Ownable.sol
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)
pragma solidity >=0.8.2 <0.9.0;

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/SightseaV1.sol

contract SightseaV1 is Ownable {
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    event Trade(
        address trader,
        address subject,
        bool isBuy,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 supply
    );

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    uint256 public totalSubjects;
    address[] public allSubjects;

    // Address => Is Subject
    mapping(address => bool) public isSubject;

    // Address => Keys of user
    mapping(address => address[]) internal _keysOfUser;

    uint256 meritPointSupply = 0;
    mapping(address => uint256) public meritPoint;
    mapping(address => uint256) public gmeritPoint;

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function getPrice(
        uint256 supply,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 sum1 = supply == 0
            ? 0
            : ((supply - 1) * (supply) * (2 * (supply - 1) + 1)) / 6;
        uint256 sum2 = supply == 0 && amount == 1
            ? 0
            : ((supply - 1 + amount) *
                (supply + amount) *
                (2 * (supply - 1 + amount) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return (summation * 1 ether) / 16000;
    }

    function getBuyPrice(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject], amount);
    }

    function getSellPrice(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject] - amount, amount);
    }

    function getBuyPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        return price + protocolFee + subjectFee;
    }

    function getSellPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        return price - protocolFee - subjectFee;
    }

    function buyShares(address sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        require(
            supply > 0 || sharesSubject == msg.sender,
            "Only the shares' subject can buy the first share"
        );
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        require(
            msg.value >= price + protocolFee + subjectFee,
            "Insufficient payment"
        );
        sharesBalance[sharesSubject][msg.sender] =
            sharesBalance[sharesSubject][msg.sender] +
            amount;
        sharesSupply[sharesSubject] = supply + amount;

        if (!isSubject[sharesSubject]) {
            isSubject[sharesSubject] = true;
            totalSubjects = totalSubjects + 1;
            allSubjects.push(sharesSubject);
        }

        bool hasKey = false;
        for (uint256 i = 0; i < _keysOfUser[msg.sender].length; i++) {
            if (_keysOfUser[msg.sender][i] == sharesSubject) {
                hasKey = true;
                break;
            }
        }
        if (!hasKey) {
            _keysOfUser[msg.sender].push(sharesSubject);
        }
        emit Trade(
            msg.sender,
            sharesSubject,
            true,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply + amount
        );
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");
    }

    function sellShares(address sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        require(
            sharesBalance[sharesSubject][msg.sender] >= amount,
            "Insufficient shares"
        );
        sharesBalance[sharesSubject][msg.sender] =
            sharesBalance[sharesSubject][msg.sender] -
            amount;
        sharesSupply[sharesSubject] = supply - amount;

        if (sharesSupply[sharesSubject] == 0) {
            isSubject[sharesSubject] = false;
            totalSubjects = totalSubjects - 1;
        }

        emit Trade(
            msg.sender,
            sharesSubject,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply - amount
        );
        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }

    function getAllKeysOfUser(
        address user
    ) public view returns (address[] memory) {
        return _keysOfUser[user];
    }

    function getAllKeyInMarket() public view returns (address[] memory) {
        return allSubjects;
    }

    function setMeritPointSupply(uint256 amount) public onlyOwner {
        meritPointSupply = amount;
    }

    function getMeritPointSupply() public view returns (uint256) {
        return meritPointSupply;
    }

    function addMeritPoint(address user, uint256 amount) public onlyOwner {
        meritPoint[user] = meritPoint[user] + amount;
    }

    function addGMeritPoint(address user, uint256 amount) public onlyOwner {
        require(meritPointSupply >= amount, "Insufficient merit point supply");
        meritPointSupply = meritPointSupply - amount;
        gmeritPoint[user] = gmeritPoint[user] + amount;
    }

    function tranferMeritPoint(
        address from,
        address to,
        uint256 amount
    ) public {
        require(gmeritPoint[from] >= amount, "Insufficient gmerit point");
        gmeritPoint[from] = gmeritPoint[from] - amount;
        meritPoint[to] = meritPoint[to] + amount;
    }

    function resetMeritPointSupply() public onlyOwner {
        meritPointSupply = 0;
    }

    function resetGMeritPointOfUser(address user) public onlyOwner {
        gmeritPoint[user] = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./Ownable.sol";

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

    function buyShares(
        address from,
        address sharesSubject,
        uint256 amount
    ) public onlyOwner {
        uint256 supply = sharesSupply[sharesSubject];
        require(
            supply > 0 || sharesSubject == from,
            "Only the shares' subject can buy the first share"
        );

        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;

        sharesBalance[sharesSubject][from] =
            sharesBalance[sharesSubject][from] +
            amount;
        sharesSupply[sharesSubject] = supply + amount;

        if (!isSubject[sharesSubject]) {
            isSubject[sharesSubject] = true;
            totalSubjects = totalSubjects + 1;
            allSubjects.push(sharesSubject);
        }

        bool hasKey = false;
        for (uint256 i = 0; i < _keysOfUser[from].length; i++) {
            if (_keysOfUser[from][i] == sharesSubject) {
                hasKey = true;
                break;
            }
        }

        if (!hasKey) {
            _keysOfUser[from].push(sharesSubject);
        }

        emit Trade(
            from,
            sharesSubject,
            true,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply + amount
        );
    }

    function sellShares(
        address from,
        address sharesSubject,
        uint256 amount
    ) public onlyOwner {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");

        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;

        require(
            sharesBalance[sharesSubject][from] >= amount,
            "Insufficient shares"
        );
        sharesBalance[sharesSubject][from] =
            sharesBalance[sharesSubject][from] -
            amount;
        sharesSupply[sharesSubject] = supply - amount;

        if (sharesSupply[sharesSubject] == 0) {
            isSubject[sharesSubject] = false;
            totalSubjects = totalSubjects - 1;
        }

        emit Trade(
            from,
            sharesSubject,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply - amount
        );
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

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "./Ownable.sol";

contract SightseaV3 is Ownable {
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    struct Point {
        address owner;
        uint256 expire;
        bool isTranfer;
    }

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

    // Address => Point[]
    Point[] internal _points;
    mapping(address => Point[]) internal pointsOfUser;

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

    function getTotalKeyOfUser(address user) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _keysOfUser[user].length; i++) {
            total = total + sharesBalance[_keysOfUser[user][i]][user];
        }

        return total;
    }

    function getTotalBalanceOfUser(address user) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _keysOfUser[user].length; i++) {
            total =
                total +
                getSellPrice(
                    _keysOfUser[user][i],
                    sharesBalance[_keysOfUser[user][i]][user]
                );
        }
        return total;
    }

    function getAllKeyInMarket() public view returns (address[] memory) {
        address[] memory keys = new address[](totalSubjects);
        uint256 index = 0;
        for (uint256 i = 0; i < allSubjects.length; i++) {
            if (isSubject[allSubjects[i]]) {
                keys[index] = allSubjects[i];
                index = index + 1;
            }
        }
        return keys;
    }

    function getTotalKeyInMarket() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < allSubjects.length; i++) {
            total = total + sharesSupply[allSubjects[i]];
        }
        return total;
    }

    function createPoint(uint256 amount, uint256 expire) public onlyOwner {
        Point memory point = Point(_msgSender(), expire, false);
        for (uint256 i = 0; i < amount; i++) {
            _points.push(point);
        }
    }

    function removePointExpired() public onlyOwner {
        for (uint256 i = _points.length; i > 0; i--) {
            _points.pop();
        }
    }

    function removePointOfUserExpired(address user) public onlyOwner {
        for (uint256 i = 0; i < pointsOfUser[user].length; i++) {
            // only remove point of user when isTranfer = false and expire < block.timestamp
            if (
                !pointsOfUser[user][i].isTranfer &&
                pointsOfUser[user][i].expire < block.timestamp
            ) {
                pointsOfUser[user][i] = pointsOfUser[user][
                    pointsOfUser[user].length - 1
                ];
                pointsOfUser[user].pop();
            }
        }
    }

    function getPercenRandom(address user) public view returns (uint256) {
        uint256 totalKey = getTotalKeyInMarket();
        uint256 totalKeyOfUser = getTotalKeyOfUser(user);

        // calculate percent of user => 1 - 1000
        uint256 percent = (totalKeyOfUser * 1000) / totalKey;

        return percent;
    }

    function randomPointForUser(address user, uint256 amount) public payable {
        require(_points.length >= amount, "The number of points is not enough");
        // check user random point in week
        // if user random point in week, checkIsRandom = true
        bool checkIsRandom = false;
        for (uint256 i = 0; i < pointsOfUser[user].length; i++) {
            if (
                pointsOfUser[user][i].expire >
                block.timestamp - (1 weeks - 1 days)
            ) {
                checkIsRandom = true;
                break;
            }
        }

        require(!checkIsRandom, "The user has random point in week");

        // logic random point
        uint256 percent = getPercenRandom(user);

        // random a number from 0 to 1000
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, percent))
        ) % 1000;

        // check random number in range of percent
        if (randomNumber > percent) {
            revert("Good luck next time");
        }

        for (uint256 i = 0; i < amount; i++) {
            pointsOfUser[user].push(_points[i]);
            _points[i] = _points[_points.length - 1];
            _points.pop();
        }
    }

    function getPointsOfUser(
        address user
    ) public view returns (Point[] memory) {
        return pointsOfUser[user];
    }

    function getTotalPointOfUser(address user) public view returns (uint256) {
        return pointsOfUser[user].length;
    }

    function tranferPoint(address from, address to, uint256 amount) public {
        uint256 pointCanTransfer = 0;
        for (uint256 i = 0; i < pointsOfUser[from].length; i++) {
            if (!pointsOfUser[from][i].isTranfer) {
                pointCanTransfer = pointCanTransfer + 1;
            }
        }

        require(pointCanTransfer >= amount, "The user does not enough points");

        uint256 count = 0;
        for (uint256 i = 0; i < pointsOfUser[from].length; i++) {
            if (!pointsOfUser[from][i].isTranfer) {
                count = count + 1;
                pointsOfUser[from][i].isTranfer = true;
                pointsOfUser[from][i].owner = to;

                pointsOfUser[to].push(pointsOfUser[from][i]);
                pointsOfUser[from][i] = pointsOfUser[from][
                    pointsOfUser[from].length - 1
                ];
                pointsOfUser[from].pop();
            }
            if (count == amount) {
                break;
            }
        }
    }

    function getPointApplication() public view returns (uint256) {
        return _points.length;
    }
}

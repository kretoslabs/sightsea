// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract Scheduler {
    address public owner;
    uint256 public lastExecution;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        // Set the initial time of deployment as the last execution time
        lastExecution = block.timestamp;
    }

    function runTask() external onlyOwner {
        // Ensure that at least 1 week have passed since the last execution
        require(
            block.timestamp >= lastExecution + 1 weeks,
            "1 week have not passed yet"
        );

        // Perform the task here
        // ... (Add your task logic here)

        // Update the last execution time
        lastExecution = block.timestamp;
    }
}

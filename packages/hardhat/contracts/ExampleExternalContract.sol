// SPDX-License-Identifier: MIT
pragma solidity 0.8.30; //Do not change the solidity version as it negatively impacts submission grading

contract ExampleExternalContract {
    bool public completed;

    function complete() public payable {
        completed = true;
    }
}

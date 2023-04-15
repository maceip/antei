// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract OnlyAuthorized {
    address public owner = msg.sender;

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner");
        _;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    uint256 public n;

    function setN(uint256 n_) public {
        n = n_;
    }
}

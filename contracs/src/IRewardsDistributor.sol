// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRewardsDistributor {
    function claim_many(uint256[] memory _tokenIds) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@oz-upgradeable/security/PausableUpgradeable.sol";
import "@oz-upgradeable/access/OwnableUpgradeable.sol";
import "@oz-upgradeable/proxy/utils/Initializable.sol";

contract UvelocityVelodrome is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    uint256 public x;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _x) public initializer {
        __Pausable_init();
        __Ownable_init();
        x = _x;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

contract UvelocityVelodromeV2 is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    uint256 public x;
    uint256 public y;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setY(uint256 _y) external {
        y = _y;
    }
}

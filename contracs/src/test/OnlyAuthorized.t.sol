// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@std/Test.sol";

import "./utils/Caller.sol";

import {OnlyAuthorized} from "../OnlyAuthorized.sol";

contract OnlyAuthorizedTest is Test {
    OnlyAuthorized private oa;

    function setUp() public {
        oa = new OnlyAuthorized();
    }

    function testCanChangeOwner() public {
        oa.changeOwner(address(0x1));
        assertEq(oa.owner(), address(0x1));
    }

    function testOtherUsersCannotChangeOwner() public {
        Caller user = new Caller();

        (bool ok, ) = user.externalCall(
            address(oa),
            abi.encodeWithSelector(
                oa.changeOwner.selector,
                (address(0xdeadbeef))
            )
        );

        assertTrue(!ok, "Only the owner can change owner");
    }
}

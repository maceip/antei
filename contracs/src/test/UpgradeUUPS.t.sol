// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

import {PRBTest} from "@prb/test/PRBTest.sol";
import "@std/console.sol";

import "../UpgradeUUPS.sol";

contract _Test is PRBTest {
    UUvelocityVelodrome implementationV1;
    UUPSProxy proxy;
    UUvelocityVelodrome wrappedProxyV1;
    UUvelocityVelodromeV2 wrappedProxyV2;

    function setUp() public {
        implementationV1 = new UUvelocityVelodrome();
        // deploy proxy contract and point it to implementation

        proxy = new UUPSProxy(address(implementationV1), "");

        // wrap in ABI to support easier calls
        wrappedProxyV1 = UUvelocityVelodrome(address(proxy));

        wrappedProxyV1.initialize(100);
    }

    function testCanInitialize() public {
        assertEq(wrappedProxyV1.x(), 100);
    }

    function testCanUpgrade() public {
        UUvelocityVelodromeV2 implementationV2 = new UUvelocityVelodromeV2();
        wrappedProxyV1.upgradeTo(address(implementationV2));

        // re-wrap the proxy
        wrappedProxyV2 = UUvelocityVelodromeV2(address(proxy));

        assertEq(wrappedProxyV2.x(), 100);

        wrappedProxyV2.setY(200);
        assertEq(wrappedProxyV2.y(), 200);
    }
}

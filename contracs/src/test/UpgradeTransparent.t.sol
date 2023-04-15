// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

import {PRBTest} from "@prb/test/PRBTest.sol";
import "@std/console.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@mock/MockProvider.sol";
import "../UpgradeTransparent.sol";

contract _Test is PRBTest {
    UvelocityVelodrome implementationV1;
    TransparentUpgradeableProxy proxy;
    UvelocityVelodrome wrappedProxyV1;
    UvelocityVelodromeV2 wrappedProxyV2;
    ProxyAdmin admin;

    function setUp() public {
        MockProvider provider = new MockProvider();
        admin = new ProxyAdmin();

        implementationV1 = new UvelocityVelodrome();

        // deploy proxy contract and point it to implementation
        proxy = new TransparentUpgradeableProxy(
            address(implementationV1),
            address(admin),
            ""
        );

        // wrap in ABI to support easier calls
        wrappedProxyV1 = UvelocityVelodrome(address(proxy));

        wrappedProxyV1.initialize(100);
    }

    function testCanInitialize() public {
        assertEq(wrappedProxyV1.x(), 100);
    }

    function testCanUpgrade() public {
        UvelocityVelodromeV2 implementationV2 = new UvelocityVelodromeV2();
        admin.upgrade(proxy, address(implementationV2));

        // re-wrap the proxy
        wrappedProxyV2 = UvelocityVelodromeV2(address(proxy));

        assertEq(wrappedProxyV2.x(), 100);

        wrappedProxyV2.setY(200);
        assertEq(wrappedProxyV2.y(), 200);
    }

    function testOnlyInitializeOnce() public {
        vm.expectRevert("Initializable: contract is already initialized");
        wrappedProxyV1.initialize(100);
    }
}

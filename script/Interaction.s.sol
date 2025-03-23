// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Stake} from "src/Stake.sol";
import {HelperConfig, CodeConstantVariable} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/Mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSub is Script {
    function createSubUsingConfig() public returns (uint256, address) {
        HelperConfig hconfig = new HelperConfig();
        address vrfcoordinator = hconfig.getConfig().vrfcoordinator;
        address account = hconfig.getConfig().account;
        // creating subscrip
        return createSub(vrfcoordinator, account);
    }

    function createSub(
        address vrfcoordinator,
        address account
    ) public returns (uint256, address) {
        console.log("Creating Subscription on Chain Id: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfcoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Your generated Subscription Id is:", subId);
        console.log("Update the SubId in your HelperConfig.s.sol");
        return (subId, vrfcoordinator);
    }

    function run() external returns (uint256, address) {
        return createSubUsingConfig();
    }
}

contract fundSubscription is Script, CodeConstantVariable {
    uint256 public constant AMOUNT_TO_BE_FUNDED = 5 ether; // 2 LINK bothe are e18

    function fundSubUsingConfig() public {
        HelperConfig hconfig = new HelperConfig();
        address vrfcoordinator = hconfig.getConfig().vrfcoordinator;
        uint256 subId = hconfig.getConfig().subId;
        address link = hconfig.getConfig().link;
        address account = hconfig.getConfig().account;

        if (subId == 0) {
            CreateSub createsub = new CreateSub();
            (uint256 updateSubId, address updateVRF) = createsub.run();
            subId = updateSubId;
            vrfcoordinator = updateVRF;
            console.log(
                "New subID create:",
                subId,
                "VRF address:",
                vrfcoordinator
            );
        }
        fundSub(vrfcoordinator, subId, link, account);
    }

    function fundSub(
        address vrfcoordinator,
        uint256 subId,
        address link,
        address account
    ) public {
        console.log("Funding to SubscriptionId:", subId);
        console.log("VRFCoordinator being used:", vrfcoordinator);
        console.log("Operated on ChainId:", block.chainid);

        if (block.chainid == LOCAL_CHAINID) {
            vm.startBroadcast();

            VRFCoordinatorV2_5Mock(vrfcoordinator).fundSubscription(
                subId,
                AMOUNT_TO_BE_FUNDED
            );

            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(
                vrfcoordinator,
                AMOUNT_TO_BE_FUNDED,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address deployedMostRecently) public {
        HelperConfig hconfig = new HelperConfig();
        uint256 subId = hconfig.getConfig().subId;
        address vrfcoordinator = hconfig.getConfig().vrfcoordinator;
        address account = hconfig.getConfig().account;
        addConsumer(deployedMostRecently, vrfcoordinator, subId, account);
    }

    function addConsumer(
        address contractToAddtoVrf,
        address vrfcoordinator,
        uint256 subId,
        address account
    ) public {
        console.log("Adding Consumer Contarct:", contractToAddtoVrf);
        console.log("To VrfCOrrdinator:", vrfcoordinator);
        console.log("On Chain Id:", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfcoordinator).addConsumer(
            subId,
            contractToAddtoVrf
        );

        vm.stopBroadcast();
    }

    function run() external {
        address deployedMostRecently = DevOpsTools.get_most_recent_deployment(
            "Stake",
            block.chainid
        );
        addConsumerUsingConfig(deployedMostRecently);
    }
}

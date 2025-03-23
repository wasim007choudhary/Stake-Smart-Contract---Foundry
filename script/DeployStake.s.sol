// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Stake} from "src/Stake.sol";
import {CreateSub, fundSubscription, AddConsumer} from "script/Interaction.s.sol";

contract DeployStake is Script {
    //  function deploySmartContract() public returns (Stake, HelperConfig) {}

    function run() external returns (Stake, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig();
        AddConsumer addconsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperconfig.getConfig();

        //CreateSubbscription
        if (config.subId == 0) {
            CreateSub createSubContract = new CreateSub();

            (config.subId, config.vrfcoordinator) = createSubContract.createSub(config.vrfcoordinator, config.account);
            //fund the subscriotion
            fundSubscription fundsubscription = new fundSubscription();
            fundsubscription.fundSub(config.vrfcoordinator, config.subId, config.link, config.account);
            helperconfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        Stake stake = new Stake(
            config.entryfee,
            config.interval,
            config.vrfcoordinator,
            config.gaslane,
            config.subId,
            config.callbackgaslimit
        );

        vm.stopBroadcast();

        addconsumer.addConsumer(address(stake), config.vrfcoordinator, config.subId, config.account);

        return (stake, helperconfig);
    }
}

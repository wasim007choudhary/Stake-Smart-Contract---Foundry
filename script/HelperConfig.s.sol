// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/Mocks/LinkToken.sol";

abstract contract CodeConstantVariable {
    uint256 public constant ETHEREUM_MAINNET_CHAINID = 1;
    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAINID = 31337;
    address public constant FOUNDRY_AC_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    //Mock variables//
    uint96 public BASE_FEE__MOCK = 0.2 ether;
    uint96 public GAS_PRICE__MOCK = 1e9;
    int256 public WEI_PER_UNIT_LINK__MOCK = 5e15;
}

contract HelperConfig is CodeConstantVariable, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entryfee;
        uint256 interval;
        address vrfcoordinator;
        bytes32 gaslane;
        uint256 subId;
        uint32 callbackgaslimit;
        address link;
        address account;
    }

    NetworkConfig public localnetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public Networkconfigurations;

    constructor() {
        Networkconfigurations[SEPOLIA_ETH_CHAIN_ID] = GETsepoliaETHconfig();
        Networkconfigurations[ETHEREUM_MAINNET_CHAINID] = getEThMainnetConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return GetconfigByChainId(block.chainid);
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        Networkconfigurations[chainId] = networkConfig;
    }

    function GetconfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (Networkconfigurations[chainId].vrfcoordinator != address(0)) {
            return Networkconfigurations[chainId];
        } else if (chainId == LOCAL_CHAINID) {
            return GetAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function GETsepoliaETHconfig()
        public
        pure
        returns (NetworkConfig memory NetworkConfigForSepolia)
    {
        NetworkConfigForSepolia = NetworkConfig({
            entryfee: 0.01 ether,
            interval: 30,
            vrfcoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subId: 11608168779741999312006484943465626178810915285225979261553438772801896238819, //14851199306729541245837496072261925116240586435919815094719659157129689715932,
            callbackgaslimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x7e0FB8958F507Bf8FEF8173a16d2A3F0f2D5f6b9
        });
    }

    function getEThMainnetConfig()
        public
        pure
        returns (NetworkConfig memory NetworkConfigMainNet)
    {
        NetworkConfigMainNet = NetworkConfig({
            entryfee: 0.01 ether,
            subId: 0,
            interval: 30,
            vrfcoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            gaslane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            callbackgaslimit: 500000,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x7e0FB8958F507Bf8FEF8173a16d2A3F0f2D5f6b9
        });
    }

    function GetAnvilConfig() public returns (NetworkConfig memory) {
        if (localnetworkConfig.vrfcoordinator != address(0)) {
            return localnetworkConfig;
        }
        console2.log("Mock Contracj Deployed");
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfcoordinatorV2_5mock = new VRFCoordinatorV2_5Mock(
                BASE_FEE__MOCK,
                GAS_PRICE__MOCK,
                WEI_PER_UNIT_LINK__MOCK
            );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localnetworkConfig = NetworkConfig({
            entryfee: 0.01 ether,
            interval: 30,
            vrfcoordinator: address(vrfcoordinatorV2_5mock),
            gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //can be anything,doesnt matter here
            subId: 0, // will fix the subscription id later
            callbackgaslimit: 500000,
            link: address(link),
            account: FOUNDRY_AC_DEFAULT_SENDER
        });
        vm.deal(localnetworkConfig.account, 100 ether);
        return localnetworkConfig;
    }
}

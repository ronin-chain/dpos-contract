// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibErrorHandler } from "@fdk/libraries/LibErrorHandler.sol";
import "./20231003_REP002AndREP003_RON_NonConditional_Wrapup2Periods.s.sol";

contract Simulation_20231003_REP002AndREP003_RON_NonConditional_GatewayUpgrade_ActualProposal is
  Simulation__20231003_UpgradeREP002AndREP003_RON_NonConditional_Wrapup2Periods
{
  using LibErrorHandler for bool;

  function _hookSetDepositCount() internal pure override returns (uint256) {
    return 42671; // fork-block-number 28595746
  }

  function _hookPrankOperator() internal pure override returns (address) {
    return 0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA;
    // return 0x32015E8B982c61bc8a593816FdBf03A603EEC823;
  }

  function _afterDepositForOnlyOnRonin(Transfer.Receipt memory receipt) internal override {
    address[21] memory operators = [
      // 0x4b3844A29CFA5824F53e2137Edb6dc2b54501BeA,
      0x4a4217d8751a027D853785824eF40522c512A3Fe,
      0x32cB6da260726BB2192c4085B857aFD945A215Cb,
      0xA91D05b7c6e684F43E8Fe0c25B3c4Bb1747A2a9E,
      0xe38aFbE7738b6Ec4280A6bCa1176c1C1A928A19C,
      0xE795F18F2F5DF5a666994e839b98263Dba86C902,
      0x772112C7e5dD4ed663e844e79d77c1569a2E88ce,
      0xF0c48B7F020BB61e6A3500AbC4b4954Bde7A2039,
      0x063105D0E7215B703909a7274FE38393302F3134,
      0xD9d5b3E58fa693B468a20C716793B18A1195380a,
      0xff30Ed09E3AE60D39Bce1727ee3292fD76A6FAce,
      0x8c4AD2DC12AdB9aD115e37EE9aD2e00E343EDf85,
      0x73f5B22312B7B2B3B1Cd179fC62269aB369c8206,
      0x5e04DC8156ce222289d52487dbAdCb01C8c990f9,
      0x564DcB855Eb360826f27D1Eb9c57cbbe6C76F50F,
      0xEC5c90401F95F8c49b1E133E94F09D85b21d96a4,
      0x332253265e36689D9830E57112CD1aaDB1A773f9,
      0x236aF2FFdb611B14e3042A982d13EdA1627d9C96,
      0x54C8C42F07007D43c3049bEF6f10eA68687d43ef,
      0x66225AcC78Be789C57a11C9a18F051C779d678B5,
      0xf4682B9263d1ba9bd9Db09dA125708607d1eDd3a,
      0xc23F2907Bc11848B5d5cEdBB835e915D7b760d99
    ];
    for (uint256 i; i < operators.length; i++) {
      vm.prank(operators[i]);
      _roninGateway.depositFor(receipt);
    }
  }

  function run() public virtual override {
    Simulation__20231003_UpgradeREP002AndREP003_Base.run();

    // -------------- Add operators Ronin Bridge --------------------

    vm.prank(0x3200A8eb56767c3760e108Aa27C65bfFF036d8E6);
    vm.resumeGasMetering();
    (bool success, bytes memory returnOrRevertData) = address(_roninBridgeManager).call(
      hex"663ac01100000000000000000000000000000000000000000000000000000000653cba7e00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000bc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000980000000000000000000000000000000000000000000000000000000000000090401a5f43f000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000620000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000016000000000000000000000000e880802580a1fbdef67ace39d1b21c5b2c74f0590000000000000000000000004b18cebeb9797ea594b5977109cc07b21c37e8c3000000000000000000000000a441f1399c8c023798586fbbbcf35f27279638a100000000000000000000000072a69b04b59c36fced19ac54209bef878e84fcbf000000000000000000000000e258f9996723b910712d6e67ada4eafc15f7f101000000000000000000000000020dd9a5e318695a61dda88db7ad077ec306e3e90000000000000000000000002d593a0087029501ee419b9415dec3fac195fe4a0000000000000000000000009b0612e43855ef9a7c329ee89653ba45273b550e00000000000000000000000047cfcb64f8ea44d6ea7fab32f13efa2f8e65eec1000000000000000000000000ad23e87306aa3c7b95ee760e86f40f3021e5fa18000000000000000000000000bacb04ea617b3e5eee0e3f6e8fcb5ba886b8395800000000000000000000000077ab649caa7b4b673c9f2cf069900df48114d79d0000000000000000000000000dca20728c8bb7173d3452559f40e95c609157990000000000000000000000000d48adbdc523681c0dee736dbdc4497e02bec210000000000000000000000000ea172676e4105e92cc52dbf45fd93b274ec96676000000000000000000000000ed448901cc62be10c5525ba19645ddca1fd9da1d0000000000000000000000008d4f4e4ba313c4332e720445d8268e087d5c19b800000000000000000000000058abcbcab52dee942491700cd0db67826bbaa8c60000000000000000000000004620fb95eabdab4bf681d987e116e0aaef1adef2000000000000000000000000c092fa0c772b3c850e676c57d8737bb39084b9ac00000000000000000000000060c4b72fc62b3e3a74e283aa9ba20d61dd4d8f1b000000000000000000000000ed3805fb65ff51a99fef4676bdbc97abeca93d1100000000000000000000000000000000000000000000000000000000000000160000000000000000000000004b3844a29cfa5824f53e2137edb6dc2b54501bea0000000000000000000000004a4217d8751a027d853785824ef40522c512a3fe00000000000000000000000032cb6da260726bb2192c4085b857afd945a215cb000000000000000000000000a91d05b7c6e684f43e8fe0c25b3c4bb1747a2a9e000000000000000000000000e38afbe7738b6ec4280a6bca1176c1c1a928a19c000000000000000000000000e795f18f2f5df5a666994e839b98263dba86c902000000000000000000000000772112c7e5dd4ed663e844e79d77c1569a2e88ce000000000000000000000000f0c48b7f020bb61e6a3500abc4b4954bde7a2039000000000000000000000000063105d0e7215b703909a7274fe38393302f3134000000000000000000000000d9d5b3e58fa693b468a20c716793b18a1195380a000000000000000000000000ff30ed09e3ae60d39bce1727ee3292fd76a6face0000000000000000000000008c4ad2dc12adb9ad115e37ee9ad2e00e343edf8500000000000000000000000073f5b22312b7b2b3b1cd179fc62269ab369c82060000000000000000000000005e04dc8156ce222289d52487dbadcb01c8c990f9000000000000000000000000564dcb855eb360826f27d1eb9c57cbbe6c76f50f000000000000000000000000ec5c90401f95f8c49b1e133e94f09d85b21d96a4000000000000000000000000332253265e36689d9830e57112cd1aadb1a773f9000000000000000000000000236af2ffdb611b14e3042a982d13eda1627d9c9600000000000000000000000054c8c42f07007d43c3049bef6f10ea68687d43ef00000000000000000000000066225acc78be789c57a11c9a18f051c779d678b5000000000000000000000000f4682b9263d1ba9bd9db09da125708607d1edd3a000000000000000000000000c23f2907bc11848b5d5cedbb835e915d7b760d99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064e9c034980000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000032015e8b982c61bc8a593816fdbf03a603eec823000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000098968000000000000000000000000000000000000000000000000000000000000f4240"
    );

    success.handleRevert(msg.sig, returnOrRevertData);

    vm.pauseGasMetering();
    require(success, "internal call failed");

    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);

    // -------------- Day #1 --------------------

    address[12] memory governors = [
      0x02201F9bfD2FaCe1b9f9D30d776E77382213Da1A,
      0x4620fb95eaBDaB4Bf681D987e116e0aAef1adEF2,
      0x5832C3219c1dA998e828E1a2406B73dbFC02a70C,
      0x58aBcBCAb52dEE942491700CD0DB67826BBAA8C6,
      0x60c4B72fc62b3e3a74e283aA9Ba20d61dD4d8F1b,
      0x77Ab649Caa7B4b673C9f2cF069900DF48114d79D,
      0x90ead0E8d5F5Bf5658A2e6db04535679Df0f8E43,
      0xbaCB04eA617b3E5EEe0E3f6E8FCB5Ba886B83958,
      0xD5877c63744903a459CCBa94c909CDaAE90575f8,
      0xe258f9996723B910712D6E67ADa4EafC15F7F101,
      0xe880802580a1fbdeF67ACe39D1B21c5b2C74f059,
      0xea172676E4105e92Cc52DBf45fD93b274eC96676
    ];

    vm.prank(governors[0]);
    (success, returnOrRevertData) = address(_roninGovernanceAdmin).call(
      hex"663ac01100000000000000000000000000000000000000000000000000000000653cba7e00000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000054000000000000000000000000000000000000000000000000000000000000012e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000617c5d73662282ea7ffd231e020eca6d2b0d552f000000000000000000000000617c5d73662282ea7ffd231e020eca6d2b0d552f000000000000000000000000545edb750eb8769c868429be9586f5857a768758000000000000000000000000ebfff2b32fa0df9c5c8c5d5aaa7e8b51d5207ba3000000000000000000000000ebfff2b32fa0df9c5c8c5d5aaa7e8b51d5207ba300000000000000000000000098d0230884448b3e2f09a177433d60fb1e19c0900000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000c768423a2ae2b5024cb58f3d6449a8f5db6d8816000000000000000000000000c768423a2ae2b5024cb58f3d6449a8f5db6d88160000000000000000000000006f45c1f8d84849d497c6c0ac4c3842dc82f498940000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000796a163a21e9a659fc9773166e0afdc1eb01aad10000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000273cda3afe17eb7bcb028b058382a9010ae82b240000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000054000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000072000000000000000000000000000000000000000000000000000000000000007e000000000000000000000000000000000000000000000000000000000000008a000000000000000000000000000000000000000000000000000000000000009600000000000000000000000000000000000000000000000000000000000000a200000000000000000000000000000000000000000000000000000000000000ae00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000c400000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000d2000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000000c1dee1b435c464b4e94781f94f991cb90e3399d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000a30b2932cd8b8a89e34551cdfa13810af38da576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000008ae952d538e9c25120e9c75fba0718750f81313a000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a44f1ef286000000000000000000000000440baf1c4b008ee4d617a83401f06aa80f5163e90000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002429b6eca9000000000000000000000000946397dedfd2f79b75a72b322944a21c3240c9c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000840ebf1ca767cb690029e91856a357a43b85d035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000243659cfe60000000000000000000000000aada85a2b3c9fb1be158d43e71cdcca6fe85e020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef286000000000000000000000000e4ccf400e99cb07eb76d3a169532916069b7dc32000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000007ccbb3cd1b19bc1f1d5b7048400d41b1b796abad000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243c3d84100000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef286000000000000000000000000ca9f10769292f26850333264d618c1b5e91f394d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000001477db6bf449b0eb1191a1f4023867ddceadc504000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e44bb5274a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000084ca21287e0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000273cda3afe17eb7bcb028b058382a9010ae82b24000000000000000000000000796a163a21e9a659fc9773166e0afdc1eb01aad1000000000000000000000000946397dedfd2f79b75a72b322944a21c3240c9c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043b1544550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000644bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000043b154455000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043b1544550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000248f2839700000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f4240"
    );
    require(success, "internal call failed");

    success.handleRevert(msg.sig, returnOrRevertData);

    // -------------- Day #2 (execute proposal on ronin) --------------------
    LibWrapUpEpoch.wrapUpPeriod();

    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);

    // -- execute proposal

    for (uint256 i = 1; i < governors.length - 3; i++) {
      vm.prank(governors[i]);
      (success, returnOrRevertData) = address(_roninGovernanceAdmin).call(
        hex"a8a0e32c00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000007e400000000000000000000000000000000000000000000000000000000653cba7e00000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000013000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000617c5d73662282ea7ffd231e020eca6d2b0d552f000000000000000000000000617c5d73662282ea7ffd231e020eca6d2b0d552f000000000000000000000000545edb750eb8769c868429be9586f5857a768758000000000000000000000000ebfff2b32fa0df9c5c8c5d5aaa7e8b51d5207ba3000000000000000000000000ebfff2b32fa0df9c5c8c5d5aaa7e8b51d5207ba300000000000000000000000098d0230884448b3e2f09a177433d60fb1e19c0900000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000c768423a2ae2b5024cb58f3d6449a8f5db6d8816000000000000000000000000c768423a2ae2b5024cb58f3d6449a8f5db6d88160000000000000000000000006f45c1f8d84849d497c6c0ac4c3842dc82f498940000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000796a163a21e9a659fc9773166e0afdc1eb01aad10000000000000000000000003fb325b251ee80945d3fc8c7692f5affca1b8bc2000000000000000000000000273cda3afe17eb7bcb028b058382a9010ae82b240000000000000000000000000cf8ff40a508bdbc39fbe1bb679dcba64e65c7df0000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000054000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000072000000000000000000000000000000000000000000000000000000000000007e000000000000000000000000000000000000000000000000000000000000008a000000000000000000000000000000000000000000000000000000000000009600000000000000000000000000000000000000000000000000000000000000a200000000000000000000000000000000000000000000000000000000000000ae00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000c400000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000d2000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000000c1dee1b435c464b4e94781f94f991cb90e3399d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000a30b2932cd8b8a89e34551cdfa13810af38da576000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000008ae952d538e9c25120e9c75fba0718750f81313a000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a44f1ef286000000000000000000000000440baf1c4b008ee4d617a83401f06aa80f5163e90000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002429b6eca9000000000000000000000000946397dedfd2f79b75a72b322944a21c3240c9c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb000000000000000000000000840ebf1ca767cb690029e91856a357a43b85d035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000243659cfe60000000000000000000000000aada85a2b3c9fb1be158d43e71cdcca6fe85e020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef286000000000000000000000000e4ccf400e99cb07eb76d3a169532916069b7dc32000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000007ccbb3cd1b19bc1f1d5b7048400d41b1b796abad000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243c3d84100000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef286000000000000000000000000ca9f10769292f26850333264d618c1b5e91f394d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844f1ef2860000000000000000000000001477db6bf449b0eb1191a1f4023867ddceadc504000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000045cd8a76b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000844bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000243101cfcb0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e44bb5274a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000084ca21287e0000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a000000000000000000000000273cda3afe17eb7bcb028b058382a9010ae82b24000000000000000000000000796a163a21e9a659fc9773166e0afdc1eb01aad1000000000000000000000000946397dedfd2f79b75a72b322944a21c3240c9c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043b1544550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000644bb5274a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000043b154455000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043b1544550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000248f2839700000000000000000000000005fa49e6ca54a9daa8eca4f403adbde5ee075d84a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000f4240"
      );

      success.handleRevert(msg.sig, returnOrRevertData);
    }
    // -- done execute proposal

    // Deposit for
    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);
    // _depositFor("after-upgrade-REP2");
    // _dummySwitchNetworks();
    _depositForOnlyOnRonin("after-upgrade-REP2");

    LibWrapUpEpoch.fastForwardToNextDay();
    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);
    _depositForOnlyOnRonin("after-upgrade-REP2_a");

    LibWrapUpEpoch.fastForwardToNextDay();
    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);
    _depositForOnlyOnRonin("after-upgrade-REP2_b");

    // -------------- End of Day #2 --------------------

    // - wrap up period
    LibWrapUpEpoch.wrapUpPeriod();

    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);
    _depositForOnlyOnRonin("after-wrapup-Day2"); // share bridge reward here
    // _depositFor("after-DAY2");

    LibWrapUpEpoch.fastForwardToNextDay();
    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);
    _depositForOnlyOnRonin("after-wrapup-Day2_a");

    // - deposit for

    // -------------- End of Day #3 --------------------
    // - wrap up period
    LibWrapUpEpoch.wrapUpPeriod();

    vm.warp(vm.getBlockTimestamp() + 3 seconds);
    vm.roll(vm.getBlockNumber() + 1);
    _depositForOnlyOnRonin("after-wrapup-Day3"); // share bridge reward here
  }
}

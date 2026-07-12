// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DeepCredCore.sol";
import "../src/DeepCredAgent.sol";

contract DeployScript is Script {
    function run() external {
        // Lấy private key từ config (user request: 4d91a393c066e8f8c8efaf70e7304bb3b05c5756c1c552a6071b25c4199f1bec)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Cấu hình không dùng legacy tx và priority fee cao
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Core
        DeepCredCore core = new DeepCredCore();
        
        // 2. Deploy Agent
        DeepCredAgent agent = new DeepCredAgent(address(core));
        
        // 3. Set Agent on Core
        core.setAgentAddress(address(agent));
        
        // 4. Cấp phí vào RitualWallet cho Scheduler/Agent hoạt động
        address RITUAL_WALLET = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;
        (bool success, ) = RITUAL_WALLET.call{value: 0.1 ether}(
            abi.encodeWithSignature("payFee()")
        );
        require(success, "Failed to deposit fee to RitualWallet");

        vm.stopBroadcast();
    }
}

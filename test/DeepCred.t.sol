// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeepCredCore.sol";
import "../src/DeepCredAgent.sol";

// Mock contract for RitualWallet
contract MockRitualWallet {
    uint256 public balance;
    function payFee() external payable {
        balance += msg.value;
    }
}

// Mock contract for Scheduler
contract MockScheduler {
    function schedule(
        address target, bytes calldata data, uint256 value, uint256 gasLimit,
        uint256 priorityFee, uint256 startTimestamp, uint256 interval, uint256 repeatCount,
        uint256 maxGasPrice, bytes32 extraConfig
    ) external returns (bytes32 taskId) {
        return keccak256(abi.encodePacked(target, data, startTimestamp));
    }
}

contract DeepCredTest is Test {
    DeepCredCore core;
    DeepCredAgent agent;

    address borrower = address(0x123);
    address admin = address(this);
    
    address constant ASYNC_DELIVERY = 0x5A16214fF555848411544b005f7Ac063742f39F6;
    address constant RITUAL_WALLET = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;
    address constant SCHEDULER = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;

    function setUp() public {
        // Mock RitualWallet & Scheduler using vm.etch
        MockRitualWallet walletMock = new MockRitualWallet();
        vm.etch(RITUAL_WALLET, address(walletMock).code);

        MockScheduler schedulerMock = new MockScheduler();
        vm.etch(SCHEDULER, address(schedulerMock).code);

        core = new DeepCredCore();
        agent = new DeepCredAgent(address(core));
        
        core.setAgentAddress(address(agent));
        
        vm.deal(borrower, 10 ether);
    }

    function test_applyAndCallbackSuccess() public {
        vm.startPrank(borrower);
        core.applyForCredit{value: 0.01 ether}("https://dummy.com/data");
        vm.stopPrank();

        DeepCredCore.BusinessCredit memory credit = core.getBusinessCredit(borrower);
        assertEq(uint(credit.status), uint(DeepCredCore.Status.PENDING));
        bytes32 jobId = credit.activeJobId;
        assertTrue(jobId != bytes32(0));

        // Simulate Callback from AsyncDelivery
        bytes memory resultData = abi.encode(uint256(800), uint256(50000 * 1e18), true);
        
        vm.startPrank(ASYNC_DELIVERY);
        agent.onAsyncResult(jobId, resultData);
        vm.stopPrank();

        credit = core.getBusinessCredit(borrower);
        assertEq(uint(credit.status), uint(DeepCredCore.Status.APPROVED));
        assertEq(credit.creditLimit, 50000 * 1e18);
        assertEq(credit.lastUpdatedScore, 800);
        assertEq(credit.activeJobId, bytes32(0)); // Lock released
    }

    function test_bypassPrecompilesMode() public {
        core.setBypassMode(true);

        vm.startPrank(borrower);
        core.applyForCredit("https://dummy.com/data");
        vm.stopPrank();

        DeepCredCore.BusinessCredit memory credit = core.getBusinessCredit(borrower);
        assertEq(uint(credit.status), uint(DeepCredCore.Status.APPROVED));
        assertEq(credit.creditLimit, 100000 * 1e18);
        assertEq(credit.lastUpdatedScore, 850);
        assertEq(credit.activeJobId, bytes32(0)); // Lock released
    }
}

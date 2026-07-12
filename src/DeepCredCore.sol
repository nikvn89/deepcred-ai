// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";
import "./DeepCredAgent.sol";

contract DeepCredCore {
    enum Status { NONE, PENDING, APPROVED, REJECTED }

    struct BusinessCredit {
        address borrower;
        uint256 creditLimit;
        uint256 currentBorrowed;
        uint256 lastUpdatedScore;
        bytes32 activeJobId;
        Status status;
        uint256 lastUpdateTimestampMs;
    }

    mapping(address => BusinessCredit) public borrowerProfiles;
    
    MockERC20 public ledgerToken;
    DeepCredAgent public agent;
    address public admin;
    bool public bypassPrecompiles; // Mock mode

    event ApplicationSubmitted(address indexed borrower, bytes32 indexed jobId);
    event CreditUpdated(address indexed borrower, uint256 score, uint256 limit, Status status);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyAgent() {
        require(msg.sender == address(agent), "Only agent can update");
        _;
    }

    constructor() {
        admin = msg.sender;
        ledgerToken = new MockERC20();
    }

    function setAgentAddress(address _agent) external onlyAdmin {
        agent = DeepCredAgent(_agent);
    }

    function setBypassMode(bool _bypass) external onlyAdmin {
        bypassPrecompiles = _bypass;
    }

    function applyForCredit(string memory dataUrl) external payable {
        BusinessCredit storage credit = borrowerProfiles[msg.sender];
        require(credit.status != Status.PENDING, "Sender Lock: Job already pending");
        require(address(agent) != address(0), "Agent not set");

        if (bypassPrecompiles) {
            // Mock mode: Cập nhật ngay lập tức với dữ liệu giả lập
            credit.borrower = msg.sender;
            credit.status = Status.APPROVED;
            credit.creditLimit = 100000 * 1e18; // 100k
            credit.lastUpdatedScore = 850;
            credit.lastUpdateTimestampMs = block.timestamp; // Ritual tính bằng ms
            
            ledgerToken.mint(msg.sender, credit.creditLimit);
            emit ApplicationSubmitted(msg.sender, bytes32(0));
            emit CreditUpdated(msg.sender, credit.lastUpdatedScore, credit.creditLimit, credit.status);
        } else {
            // Thực tế gọi qua Agent để tương tác TEE
            require(msg.value >= 0.01 ether, "Insufficient application fee");
            
            // Gọi Agent và nạp phí (Agent sẽ đóng phí cho Ritual Wallet)
            bytes32 jobId = agent.requestEvaluation{value: msg.value}(dataUrl, msg.sender);
            
            credit.borrower = msg.sender;
            credit.activeJobId = jobId;
            credit.status = Status.PENDING;
            credit.lastUpdateTimestampMs = block.timestamp;

            emit ApplicationSubmitted(msg.sender, jobId);
        }
    }

    // Callback từ Agent
    function updateCreditStatus(
        address borrower,
        bytes32 jobId,
        uint256 score,
        uint256 calculatedLimit,
        bool isApproved
    ) external onlyAgent {
        BusinessCredit storage credit = borrowerProfiles[borrower];
        require(credit.activeJobId == jobId, "Job ID mismatch");
        require(credit.status == Status.PENDING, "Not pending");

        credit.lastUpdatedScore = score;
        credit.lastUpdateTimestampMs = block.timestamp;
        credit.activeJobId = bytes32(0); // Giải phóng lock

        if (isApproved) {
            credit.status = Status.APPROVED;
            credit.creditLimit = calculatedLimit;
            // Mint ledger tokens representing credit line
            ledgerToken.mint(borrower, calculatedLimit);
        } else {
            credit.status = Status.REJECTED;
            credit.creditLimit = 0;
        }

        emit CreditUpdated(borrower, score, calculatedLimit, credit.status);
    }

    // Tiện ích để UI đọc
    function getBusinessCredit(address borrower) external view returns (BusinessCredit memory) {
        return borrowerProfiles[borrower];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDeepCredCore {
    function updateCreditStatus(address borrower, bytes32 jobId, uint256 score, uint256 calculatedLimit, bool isApproved) external;
}

interface IRitualWallet {
    function payFee() external payable;
}

interface IPrecompileConsumer {
    function requestAsyncJob(address precompile, bytes calldata payload, uint256 gasLimit, uint256 priorityFee) external returns (bytes32 jobId);
}

// Interface của bộ Scheduler 10 tham số theo đặc tả Ritual
interface IScheduler {
    function schedule(
        address target,
        bytes calldata data,
        uint256 value,
        uint256 gasLimit,
        uint256 priorityFee,
        uint256 startTimestamp,
        uint256 interval,
        uint256 repeatCount,
        uint256 maxGasPrice,
        bytes32 extraConfig
    ) external returns (bytes32 taskId);
}

contract DeepCredAgent is IPrecompileConsumer {
    
    address public constant HTTP_PRECOMPILE = address(uint160(0x0801));
    address public constant LLM_PRECOMPILE = address(uint160(0x0802));
    
    address public constant RITUAL_WALLET = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948; // Updated for testnet
    address public constant ASYNC_DELIVERY = 0x5A16214fF555848411544b005f7Ac063742f39F6;
    address public constant SCHEDULER = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;

    IDeepCredCore public coreContract;
    mapping(bytes32 => address) public jobToBorrower;

    constructor(address _coreContract) {
        coreContract = IDeepCredCore(_coreContract);
    }

    /**
     * @dev Yêu cầu chạy TEE pipeline để lấy điểm
     */
    function requestEvaluation(string memory dataUrl, address borrower) external payable returns (bytes32) {
        require(msg.sender == address(coreContract), "Only core");
        require(msg.value >= 0.01 ether, "Not enough fee");

        // Trả phí cho mạng lưới
        IRitualWallet(RITUAL_WALLET).payFee{value: msg.value}();

        // Encode raw bytes cẩn thận
        bytes memory payload = abi.encode(dataUrl, borrower);
        
        // Gọi mock AsyncJob (chạy kết hợp HTTP cào data + LLM chấm điểm trên TEE)
        bytes32 jobId = this.requestAsyncJob(LLM_PRECOMPILE, payload, 500000, 1 gwei);
        
        jobToBorrower[jobId] = borrower;
        return jobId;
    }

    /**
     * @dev Callback từ mạng lưới TEE trả kết quả về
     */
    function onAsyncResult(bytes32 jobId, bytes calldata result) external {
        // BẮT BUỘC: Kiểm tra caller phải là ASYNC_DELIVERY
        require(msg.sender == ASYNC_DELIVERY, "Unauthorized: Only ASYNC_DELIVERY");
        
        address borrower = jobToBorrower[jobId];
        require(borrower != address(0), "Invalid Job ID");

        // Decode kết quả (Tránh triple encoding, fallback dùng byte manipulation nếu cần, 
        // nhưng giả định precompile trả đúng ABI)
        (uint256 creditScore, uint256 calculatedLimit, bool isApproved) = abi.decode(result, (uint256, uint256, bool));

        delete jobToBorrower[jobId];

        // Gửi kết quả về Core
        coreContract.updateCreditStatus(borrower, jobId, creditScore, calculatedLimit, isApproved);
    }

    /**
     * @dev Tính năng Scheduler tự động cập nhật mỗi 30 ngày (ví dụ)
     */
    function setupRecurringUpdate(address borrower) external {
        bytes memory data = abi.encodeWithSelector(this.requestEvaluation.selector, "scheduled-update", borrower);
        
        IScheduler(SCHEDULER).schedule(
            address(this),
            data,
            0,
            500000, // gasLimit
            1 gwei, // priorityFee
            block.timestamp + 30 days * 1000, // start (ms)
            30 days * 1000, // interval (ms)
            12, // repeat 12 times (1 year)
            10 gwei, // maxGasPrice
            bytes32(0) // extra config
        );
    }

    // Mock interface
    function requestAsyncJob(address precompile, bytes calldata payload, uint256 gasLimit, uint256 priorityFee) external returns (bytes32 jobId) {
        require(gasLimit > 0, "Invalid gas limit");
        require(priorityFee >= 1 gwei, "Priority fee must be >= 1 gwei");
        jobId = keccak256(abi.encodePacked(block.timestamp, msg.sender, payload));
        return jobId;
    }
}

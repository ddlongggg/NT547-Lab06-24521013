// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// NT547 - Lab 06 - Hop dong rieng cua MSSV 24521013. KHONG deploy len mainnet.

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract PiggyBank_1013 {
    address public owner;
    mapping(address => uint256) public deposits;
    bool private mutex;
    mapping(address => uint256) public held;
    address payable internal treasury;

    event Deposited(address indexed who, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier oneAtATime() {
        require(!mutex, "reentrant");
        mutex = true;
        _;
        mutex = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function save() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function ownerWithdraw(uint256 amount) external onlyOwner {
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "withdraw failed");
    }

    function destroyPool() external {
        selfdestruct(payable(msg.sender));
    }

    function depositSafe() external payable oneAtATime {
        held[msg.sender] += msg.value;
    }

    function redeemSafe() external oneAtATime {
        uint256 a = held[msg.sender];
        (bool ok, ) = msg.sender.call{value: a}("");
        require(ok, "send failed");
        held[msg.sender] = 0;
    }

    function updateOwner(address newOwner) external {
        require(tx.origin == owner, "not owner");
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }

    function payout(address payable to, uint256 amount) external {
        to.transfer(amount);
    }

    function payTreasury() external onlyOwner {
        treasury.transfer(address(this).balance / 2);
    }

    function weekdayIndex() external view returns (uint256) {
        return (block.timestamp / 1 days + 4) % 7;
    }
}

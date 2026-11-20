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
        require(tx.origin == owner, "not owner");
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
    treasury = payable(msg.sender);
    }

    function save() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function ownerWithdraw(uint256 amount) external onlyOwner {
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "withdraw failed");
    }

     function destroyPool() external onlyOwner {
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "destroy failed");
    }

    function depositSafe() external payable oneAtATime {
        held[msg.sender] += msg.value;
    }

    function redeemSafe() external oneAtATime { 
        uint256 a = held[msg.sender];
        require(a > 0, "empty");
        held[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: a}("");
        require(ok, "send failed");
    }

   function updateOwner(address newOwner) external {
        require(tx.origin == owner, "not owner");
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }

    function payout(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero");
        require(amount <= address(this).balance, "insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "payout failed");
    }

    function setTreasury(address payable newTreasury) external onlyOwner {
        require(newTreasury != address(0), "zero");
        treasury = newTreasury;
    }

    function payTreasury() external onlyOwner {
        require(treasury != address(0), "zero treasury");
        (bool ok, ) = treasury.call{value: address(this).balance / 2}("");
        require(ok, "treasury failed");
    }

    function weekdayIndex() external view returns (uint256) {
        // slither-disable-next-line weak-prng
        return (block.timestamp / 1 days + 4) % 7;
    }
}

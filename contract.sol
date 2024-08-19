// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract Wallet {
    string public str;
    address public owner;
    address[] public owners;
    mapping(address => bool) public isOwner;
    mapping(address => uint) public voteCount;
    bool public paused = false;
    uint public dailyLimit;
    uint public lastWithdrawTime;
    uint public timeLockDuration;
    uint public timeLockStart;
    address public newOwner;

    event Deposit(address indexed sender, uint amount);
    event Withdrawal(address indexed to, uint amount);
    event TransferOwnership(address indexed previousOwner, address indexed newOwner);
    event Paused();
    event Unpaused();
    event TimeLockSet(uint duration);

    constructor(address[] memory _owners, uint _dailyLimit, uint _timeLockDuration) {
        require(_owners.length > 0, "At least one owner is required");
        owner = msg.sender;
        for (uint i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        dailyLimit = _dailyLimit;
        timeLockDuration = _timeLockDuration;
        timeLockStart = block.timestamp;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "You don't have access!");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    modifier withinDailyLimit(uint _weiAmount) {
        require(block.timestamp >= lastWithdrawTime + 1 days, "Withdrawal limit reached");
        require(_weiAmount <= dailyLimit, "Amount exceeds daily limit");
        _;
    }

    modifier onlyAfterTimeLock() {
        require(block.timestamp >= timeLockStart + timeLockDuration, "Function locked by timelock");
        _;
    }

    function transfer_to_contract() external payable whenNotPaused {
        emit Deposit(msg.sender, msg.value);
    }

    function transfer_via_contract(address payable _to, uint _weiAmount) 
        external 
        onlyOwner 
        whenNotPaused 
        withinDailyLimit(_weiAmount) 
        onlyAfterTimeLock 
    {
        require(address(this).balance >= _weiAmount, "Insufficient Balance!");
        _to.transfer(_weiAmount);
        lastWithdrawTime = block.timestamp;
        emit Withdrawal(_to, _weiAmount);
    }

    function withdraw_from_contract(uint _weiAmount) 
        external 
        onlyOwner 
        whenNotPaused 
        withinDailyLimit(_weiAmount) 
        onlyAfterTimeLock 
    {
        require(address(this).balance >= _weiAmount, "Insufficient Balance!");
        payable(owner).transfer(_weiAmount);
        lastWithdrawTime = block.timestamp;
        emit Withdrawal(owner, _weiAmount);
    }

    function transfer_to_user_via_msg_value(address payable _to) 
        external 
        payable 
        whenNotPaused 
    {
        require(address(this).balance >= msg.value, "Insufficient balance");
        _to.transfer(msg.value);
        emit Withdrawal(_to, msg.value);
    }

    function get_owner_balance() external view returns(uint) {
        return owner.balance;
    }

    function recieve_from_user() external payable whenNotPaused {
        require(msg.value > 0, "Send the value greater than zero");
        payable(owner).transfer(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused();
    }

    function propose_new_owner(address _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }

    function accept_ownership() external {
        require(msg.sender == newOwner, "You are not the proposed new owner");
        emit TransferOwnership(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }

    function set_time_lock(uint _duration) external onlyOwner {
        timeLockDuration = _duration;
        timeLockStart = block.timestamp;
        emit TimeLockSet(_duration);
    }

    receive() external payable whenNotPaused {
        emit Deposit(msg.sender, msg.value);
    }

    fallback() external payable whenNotPaused {
        str = "Fallback function is called!";
        payable(msg.sender).transfer(msg.value);
    }
}

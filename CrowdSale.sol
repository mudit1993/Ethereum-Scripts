pragma solidity ^0.4.21;

interface token{
    function transfer(address recepient, uint256 amount) external;
}

contract MyToken316 {
    function mintCoins(address, uint) public pure{}
}
contract CrowdSale {
    
    address public beneficiary;
    uint256 public fundingGoal;
    uint256 public fundsRaised;
    uint256 public deadline;
    uint256 public price;
    MyToken316 public rewardToken;
    mapping(address => uint256) public balanceOf;
    bool public fundingGoalReached = false;
    bool public crowdSaleClosed = false;
    
    event GoalReached(address recepient, uint256 totalAmountRaised);
    event FundTransfer(address backer, uint256 amount, bool isContribution);
        
    function CrowdSale(address isSuccessfulSendTo,
                            uint fundingGoalInEthers,
                            uint durationInMinutes,
                            uint etherCostOfEachToken,
                            address addressOfTokenUsedAsReward) public{
        beneficiary = isSuccessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 ether;
        deadline = now + durationInMinutes * 1 minutes;
        price = etherCostOfEachToken * 1 ether;
        rewardToken = MyToken316(addressOfTokenUsedAsReward);
    }
    
    function() public payable{
        require(!crowdSaleClosed);
        uint amount = msg.value;
        balanceOf[msg.sender] += amount; 
        fundsRaised += amount;
        rewardToken.mintCoins(msg.sender,amount/price); // transfering tokens to the sender
        emit FundTransfer(msg.sender,amount,true);
    }
    
    modifier afterDeadLine(){
        if(now >= deadline)
        _;
    }
    
    function checkGoalReached() public afterDeadLine{
        if(fundsRaised >= fundingGoal){
            fundingGoalReached = true;
            emit GoalReached(beneficiary,fundsRaised);
        }
        crowdSaleClosed = true;
    }
    
    function safeWithdrawal() public afterDeadLine{
        if(!fundingGoalReached){
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0 ;
            if(amount > 0){
            if(msg.sender.send(amount)){ // transfering amount withdrawn
               fundsRaised -= amount; // reducing the raised funds as amount is withdrawn
               emit FundTransfer(msg.sender,amount,false);
            }
            else{
                balanceOf[msg.sender] = amount;
            }
                
            }
        }
        if(fundingGoalReached && beneficiary == msg.sender){
            if(beneficiary.send(fundsRaised)){
                emit FundTransfer(beneficiary,fundsRaised,false);
            }else{
                // if we fail to send funds to beneficiary, unlock funders balance
                fundingGoalReached = false;
            }
        }
    }
}
pragma solidity ^0.4.21;

contract owned {
        
    address public owner;
            
    function owned() public {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }
    
    function transferOwnership(address newOwner) onlyOwner public{
        owner = newOwner;
    }
}

interface Token{
    function transferFrom(address _from,address _to, uint value) external returns (bool success) ;
}

contract tokenReceipt {
    event ReceivedEther(address sender, uint amount);
    event ReceivedTokens(address _from, uint256 amount, address token, bytes _extraData);
    
    function receiveApproval(address _from, uint256 amount, address _token , bytes _extraData) public{
        Token t  = Token(_token);
        require(t.transferFrom(_from,this,amount));
        emit ReceivedTokens(_from,amount,_token,_extraData);
    }
    
    function() payable public{
        emit ReceivedEther(msg.sender,msg.value);
    }
}

contract Congress is owned,tokenReceipt{
    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    int public majorityMargin;
    Proposal[] public proposals;
    uint public numProposals;
    Member[] public members;
    mapping(address => uint) public memberId;
    
    event ProposalAdded(uint proposalId,address recipient,uint amount, string description);
    event Voted(uint proposalId, bool position, address voter,string justification);
    event ProposalTallied(uint proposalId,int result, uint quorum, bool active);
    event MembershipChanged(address member,bool isMember);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes, int  newMajorityMargin);

    struct Proposal{
        address recipient;
        uint amount;
        string description;
        uint minExecutionDate;
        bool executed;
        bool proposalPassed;
        uint noOfVotes;
        int currentResult;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }
    struct Member{
        address member;
        uint memberSince;
        string name;
        
    }
    struct Vote{
        address voter;
        bool inSupport;
        string justification;
    }
    
    //only shareHolders to vote and create new proposals
    modifier onlyMembers() {
        require(memberId[msg.sender] != 0);
        _;
    }

    function Congress(uint minimumQuorumForProposals,
                    uint minutesForDebate,
                    int majorityMarginOfVotes) payable public {
        changeVotingRules(minimumQuorumForProposals,minutesForDebate,majorityMarginOfVotes); 
        
        addMember(0,""); // necessary
        
        addMember(owner,"founder");
    }    
    
    function removeMember(address memberToRemove) onlyOwner public{
        require(memberId[memberToRemove] != 0);
        for(uint i = memberId[memberToRemove] ; i < members.length - 1; i++){
            members[i] = members[i+1];
        }
        delete members[members.length - 1];
        members.length--;
    }
    
    function addMember(address newMember, string memberName) onlyOwner public {
        uint id = memberId[newMember];
        if(id == 0){
            memberId[newMember] = members.length;  // updating the map with new member
            id = members.length++; 
        }
        members[id] = Member({member : newMember , memberSince : now , name : memberName});
        emit MembershipChanged(newMember,true);
        
    }
    
    
    function changeVotingRules(
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int majorityMarginOfVotes
        ) onlyOwner public{
            minimumQuorum = minimumQuorumForProposals;
            debatingPeriodInMinutes = minutesForDebate;
            majorityMargin = majorityMarginOfVotes;
            emit ChangeOfRules(minimumQuorum,debatingPeriodInMinutes,majorityMargin);
    }

    function newProposal(
        address beneficiary,
        uint weiAmount,
        string jobDescription,
        bytes transactionByteCode
        ) onlyMembers public returns (uint proposalId){
        proposalId = proposals.length++;
        Proposal storage p = proposals[proposalId];
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.description = jobDescription;
        p.proposalHash = keccak256(beneficiary,weiAmount,transactionByteCode);
        p.minExecutionDate = now + debatingPeriodInMinutes * 1 minutes;
        p.executed = false;
        p.proposalPassed = false;
        p.noOfVotes = 0;
        emit ProposalAdded(proposalId,beneficiary,weiAmount,jobDescription);
        numProposals =  proposalId + 1;
        return proposalId;
        }
        
        function proposalInEther(address beneficiary,
        uint amountInEther,
        string jobDescription,
        bytes transactionByteCode)onlyMembers public returns(uint proposalId){
            return newProposal(beneficiary,amountInEther * 1 ether, jobDescription,transactionByteCode);
        }
        
        function checkProposalCode(uint proposalNumber,
        address beneficiary,
        uint weiAmount,
        bytes transactionByteCode
        ) constant public returns(bool codeChecksOut){
            Proposal storage p = proposals[proposalNumber];
            return p.proposalHash == keccak256(beneficiary,weiAmount,transactionByteCode);
        } 
        
        function vote(
            uint proposalNumber,
            bool supportsProposal,
            string justificationText
        ) onlyMembers public returns(uint voteId) {
           Proposal storage p = proposals[proposalNumber];
           require(!p.voted[msg.sender]);
           p.voted[msg.sender] = true;
           p.noOfVotes++;
           if(supportsProposal){
               p.currentResult++;
           }else{
               p.currentResult--;
           }
           emit Voted(proposalNumber,supportsProposal,msg.sender,justificationText); 
            return p.noOfVotes;
        }
        
        function executeProposal(
            uint proposalNumber,
            bytes transactionByteCode
            )public{
        Proposal storage p = proposals[proposalNumber];
        require(now>p.minExecutionDate && !p.executed
        && p.proposalHash == keccak256(p.recipient,p.amount,transactionByteCode)
        && p.noOfVotes >= minimumQuorum);
        p.executed = true;
        // will execute result now
        if(p.currentResult>majorityMargin){
            
            require(p.recipient.call.value(p.amount)(transactionByteCode));
            p.proposalPassed = true;
        }else{
            p.proposalPassed = false;
        }
        emit ProposalTallied(proposalNumber,p.currentResult,p.noOfVotes,p.proposalPassed);
        }
}
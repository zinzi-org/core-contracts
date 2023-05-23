// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../lib/Strings.sol";
import "../lib/Timers.sol";
import "../lib/IVotes.sol";
import "../lib/SafeCast.sol";
import "../lib/Math.sol";

import "./Members.sol";
import "./MemberVote.sol";

import "hardhat/console.sol";

contract GovernorBoard {
    event Proposal(uint256 proposalId, string description, PropType pType);
    event MemberProposal(address who, uint256 proposalId, string description);
    event ApproveMember(address member, address governor);
    event AddGovernor(address governor, uint256 proposalId);
    event RemoveGovernor(address governor, uint256 proposalId);
    event RemoveMember(address member, uint256 proposalId);
    event SetProposalDuration(uint256 duration, uint256 proposalId);
    event SetDelegationThreshold(uint256 threshold, uint256 proposalId);
    event SetApplicantFee(uint256 newFee, uint256 proposalId);

    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;
    using Math for uint256;

    enum PropType {
        TEXT_BASED_PROPOSAL,
        ADD_GOVERNOR,
        REMOVE_GOVERNOR,
        REMOVE_MEMBER,
        SET_PROPOSAL_DURATION,
        SET_DELEGATION_THRESHOLD,
        APPLICANT,
        APPLICANT_FEE,
        DISTRIBUE_FUNDS
    }

    struct ProposalCore {
        PropType pType;
        Timers.BlockNumber voteStart;
        Timers.BlockNumber voteEnd;
        bool executed;
        bool canceled;
        address who;
        uint256 amount;
        ProposalVote votes;
    }

    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }

    enum ProposalState {
        Pending,   // 0
        Active,    // 1
        Canceled,  // 2
        Defeated,  // 3
        Succeeded, // 4
        Queued,    // 5
        Expired,   // 6
        Executed   // 7
    }

    IVotes private immutable _token;

    uint256 private _balance;
    uint256 private _balanceInTheory;

    uint256 private _votingDelay = 0;
    uint256 private _votingPeriod = 10000;
    uint256 private _delegatedProposalThreashold = 12;
    uint256 private _minMemberCountForDelgations = 5;
    uint256 private _applicant_Fee = 100;

    uint256 private _memberCount = 1;

    address immutable _membersContractAddress;

    mapping(uint256 => ProposalCore) private _proposals;

    address[] public _governors;
    mapping(address => uint) public _governorsMapping;

    string private _name;
    string private _symbol;

    constructor(
        address memberAddress,
        address sender,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        _name = tokenName;
        _membersContractAddress = memberAddress;
        _governors.push(sender);
        _governorsMapping[sender] = _governors.length;
        _token = IVotes(new MemberVote(tokenName, tokenSymbol, address(this)));
        _token.assignVoteToken(sender);
    }

    modifier onlyGovernor() {
        require(_governorsMapping[msg.sender] > 0);
        _;
    }

    modifier onlyMember() {
        Members members = Members(_membersContractAddress);
        uint256 tokenId = members.getTokenId(msg.sender);
        address board = members.getBoardForToken(tokenId);
        require(address(this) == board, "Not a member");
        _;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function getMemberVotesAddress() public view returns (address) {
        return address(_token);
    }

    function isGovernor(address who) public view returns (bool) {
        return (_governorsMapping[who] > 0);
    }

    function addMember(address newAddress) public onlyGovernor {
        Members members = Members(_membersContractAddress);
        members.mintTo(newAddress);
        _token.assignVoteToken(newAddress);
        _memberCount += 1;
        emit ApproveMember(newAddress, msg.sender);
    }

    function getTotalMembers() public view returns (uint256) {
        return _memberCount;
    }

    function proposalDetail(uint256 proposalId) public view returns (PropType, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        ProposalCore storage proposal = _proposals[proposalId];
        return (
            proposal.pType,
            proposal.voteStart.getDeadline(),
            proposal.voteEnd.getDeadline(),
            proposal.executed ? 1 : 0,
            proposal.canceled ? 1 : 0,
            proposal.who == address(0) ? 1 : 0,
            proposal.amount,
            proposal.votes.againstVotes,
            proposal.votes.forVotes,
            proposal.votes.abstainVotes,
            proposal.votes.hasVoted[msg.sender] ? 1 : 0,
            _applicant_Fee
        );
    }

    function getApplicantFee() public view returns (uint256) {
        return _applicant_Fee;
    }

    function proposeMember(string memory description, address who) public payable{
        require(msg.value >= _applicant_Fee, "Governor: not enough funds");
        Members members = Members(_membersContractAddress);
        uint256 balance = members.balanceOf(who);
        require(balance == 0, "Governor: member already exists");

        uint256 proposalId = hashProposal(
            PropType.APPLICANT,
            keccak256(bytes(description)),
            who
        );

        ProposalCore storage proposal = _proposals[proposalId];
        proposal.who = who;
        proposal.pType = PropType.APPLICANT;
        proposal.voteStart.setDeadline(block.number.toUint64());
        proposal.voteEnd.setDeadline(block.number.toUint64() + _votingPeriod.toUint64());
        emit MemberProposal(who, proposalId, description);
    }

    function propose(
    string memory description,
    PropType pType,
    address who,
    uint256 amount,
    uint256 votingDelay) public {
        require(
            isGovernor(msg.sender) || memberHasDelegation(msg.sender),
            "Not enough voting power to create proposal"
        );


       

        uint256 proposalId = hashProposal(
            pType,
            keccak256(bytes(description)),
            who
        );

        ProposalCore storage proposal = _proposals[proposalId];

        if (pType == PropType.ADD_GOVERNOR) {
            proposal.who = who;
        } else if (pType == PropType.REMOVE_GOVERNOR) {
            require(
                _governorsMapping[who] > 0,
                "Governor: governor does not exist"
            );
            proposal.who = who;
        } else if (pType == PropType.REMOVE_MEMBER) {
            proposal.who = who;
        } else if (pType == PropType.SET_PROPOSAL_DURATION) {
            require(amount > 0, "Governor: invalid duration");
            proposal.amount = amount;
        } else if (pType == PropType.SET_DELEGATION_THRESHOLD) {
            require(
                amount > 0 && amount <= 100,
                "Governor: invalid threshold"
            );
            proposal.amount = amount;
        } else if (pType == PropType.APPLICANT) {
            proposal.who = who;
        } else if(pType == PropType.TEXT_BASED_PROPOSAL){
            //do nothing
        } else if(pType == PropType.APPLICANT_FEE){
            require(amount >= 0, "Governor: invalid fee amount");
            proposal.amount = amount;
        } else if(pType == PropType.DISTRIBUE_FUNDS){
            require(amount >= 0, "Governor: invalid amount");
            proposal.amount = amount;
            proposal.who = who;
        } else {
            revert("Invalid proposal type");
        }

        require(
            proposal.voteStart.isUnset(),
            "Governor: proposal already exists"
        );

        uint64 snapshot = block.number.toUint64() + votingDelay.toUint64();
        uint64 deadline = snapshot + votingPeriod().toUint64();

        proposal.pType = pType;
        proposal.voteStart.setDeadline(snapshot);
        proposal.voteEnd.setDeadline(deadline);

        emit Proposal(proposalId, description, pType);
    }

    //members cannot just create proposals.. only governors can do that.. but if a member gets enough delgated votes he can create a proposal
    //he needs a certain _memberDelegationPercentatge and cannot do it with a org that has fewer than 5 members
    function memberHasDelegation(address who) public view returns (bool) {
        uint256 votes = getVotes(who, block.number - 1);
        return votes.average(_memberCount) >= _delegatedProposalThreashold;
    }

    function castVote(
        uint256 proposalId,
        uint8 support
    ) public returns (uint256) {
        return _castVote(proposalId, msg.sender, support);
    }

    function proposalVotes(
        uint256 proposalId
    )
        public
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        ProposalVote storage proposalVote = _proposals[proposalId].votes;
        return (
            proposalVote.againstVotes,
            proposalVote.forVotes,
            proposalVote.abstainVotes
        );
    }

    function hasVoted(
        uint256 proposalId,
        address account
    ) public view returns (bool) {
        return _proposals[proposalId].votes.hasVoted[account];
    }

    function hashProposal(
        PropType pType,
        bytes32 description,
        address who
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(pType, description, who)));
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        ProposalCore storage proposal = _proposals[proposalId];

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        uint256 snapshot = proposalSnapshot(proposalId);

        if (snapshot == 0) {
            revert("Governor: unknown proposal id");
        }

        if (snapshot >= block.number) {
            return ProposalState.Pending;
        }

        uint256 deadline = proposalDeadline(proposalId);

        if (deadline >= block.number) {
            return ProposalState.Active;
        }

        if (_voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    function proposalSnapshot(
        uint256 proposalId
    ) public view returns (uint256) {
        return _proposals[proposalId].voteStart.getDeadline();
    }

    function proposalDeadline(
        uint256 proposalId
    ) public view returns (uint256) {
        return _proposals[proposalId].voteEnd.getDeadline();
    }

    function votingPeriod() public view returns (uint256) {
        return _votingPeriod;
    }

    function getVotes(
        address account,
        uint256 blockNumber
    ) public view returns (uint256) {
        return _getVotes(account, blockNumber);
    }


    //Proposal Success Functions

    function addGovernor(uint256 proposalId) public {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Invalid Proposal State"
        );
        require(
             _proposals[proposalId].pType == PropType.ADD_GOVERNOR,
            "Invalid Proposal Type"
        );

        address newGov = _proposals[proposalId].who;
        _governors.push(newGov);
        _governorsMapping[newGov] = _governors.length;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit AddGovernor(newGov, proposalId);
    }

    function removeGovernor(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.REMOVE_GOVERNOR, "Invalid Proposal Type");
        address governorToRemove = _proposals[proposalId].who;
        uint256 index = _governorsMapping[governorToRemove];

        require(index > 0, "Governor not found");

        uint256 lastIndex = _governors.length - 1;
        address lastGovernor = _governors[lastIndex];

        _governors[index - 1] = lastGovernor;
        _governorsMapping[lastGovernor] = index;
        _governors.pop();
        _governorsMapping[governorToRemove] = 0;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit RemoveGovernor(governorToRemove, proposalId);
    }


    function removeMember(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.REMOVE_MEMBER, "Invalid Proposal Type");
        address memberToRemove = _proposals[proposalId].who;
        Members members = Members(_membersContractAddress);
        uint256 tokenId = members.getTokenId(memberToRemove);
        
        require(tokenId != 0, "Member not found");

        members.burn(tokenId);
        _token.burnAll(memberToRemove);
        _memberCount -= 1;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit RemoveMember(memberToRemove, proposalId);
    }

    function setProposalDuration(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.SET_PROPOSAL_DURATION, "Invalid Proposal Type");
        uint256 newDuration = _proposals[proposalId].amount;
        _votingPeriod = newDuration;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit SetProposalDuration(newDuration, proposalId);
    }

    function setDelegationThreshold(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.SET_DELEGATION_THRESHOLD, "Invalid Proposal Type");
        uint256 newThreshold = _proposals[proposalId].amount;
        _delegatedProposalThreashold = newThreshold;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit SetDelegationThreshold(newThreshold, proposalId);
    }

    function addMemberWithProposal(uint proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded || isGovernor(msg.sender), "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.APPLICANT, "Invalid Proposal Type");
        address newMember = _proposals[proposalId].who;
        Members members = Members(_membersContractAddress);
        members.mintTo(newMember);
        _token.assignVoteToken(newMember);
        _memberCount += 1;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit ApproveMember(newMember, msg.sender);
    }

    function setApplicantFee(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.APPLICANT_FEE, "Invalid Proposal Type");
        uint256 newFee = _proposals[proposalId].amount;
        _applicant_Fee = newFee;
        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;
        emit SetApplicantFee(newFee, proposalId);
    }


    function distributeFunds(uint256 proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Invalid Proposal State");
        require(_proposals[proposalId].pType == PropType.DISTRIBUE_FUNDS, "Invalid Proposal Type");
        ProposalCore storage proposal = _proposals[proposalId];
        transferFunds(proposal.who, proposal.amount);
        proposal.executed = true;
    }

    // Internal ---------------------------------------------------------------

    function transferFunds(address who, uint256 amount) internal {
        require(_balance >= amount, "Not enough funds");
        _balance -= amount;
        payable(who).transfer(amount);
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support
    ) internal returns (uint256) {
        ProposalCore storage proposal = _proposals[proposalId];
        require(
            state(proposalId) == ProposalState.Active,
            "Governor: vote not currently active"
        );

        uint256 weight = _getVotes(account, proposal.voteStart.getDeadline());
        require(weight > 0, "Weight must be greater than zero to cast vote");
        _countVote(proposalId, account, support, weight);

        return weight;
    }

    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        ProposalVote storage proposalVote = _proposals[proposalId].votes;
        return proposalVote.forVotes > proposalVote.againstVotes;
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal {
        ProposalVote storage proposalVote = _proposals[proposalId].votes;

        require(
            !proposalVote.hasVoted[account],
            "GovernorVotingSimple: vote already cast"
        );

        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.Against)) {
            proposalVote.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposalVote.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += weight;
        } else {
            revert("GovernorVotingSimple: invalid value for enum VoteType");
        }
    }

    function _getVotes(
        address account,
        uint256 blockNumber
    ) internal view returns (uint256) {
        return _token.getPastVotes(account, blockNumber);
    }
}

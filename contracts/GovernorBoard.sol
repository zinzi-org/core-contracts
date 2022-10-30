// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./lib/Strings.sol";
import "./lib/Timers.sol";
import "./lib/IVotes.sol";
import "./lib/SafeCast.sol";

import "./Members.sol";
import "./MemberVote.sol";

import "hardhat/console.sol";

contract GovernorBoard {
    using Timers for Timers.BlockNumber;
    using SafeCast for uint256;

    enum PropType {
        TEXT_BASED_PROPOSAL, //external outcome
        ADD_GOVERNOR, // we need an address
        REMOVE_GOVERNOR, // we need an address
        SET_BOARD_URL, // we need a string
        REMOVE_MEMBER // we need an address
    }

    struct ProposalCore {
        Timers.BlockNumber voteStart;
        Timers.BlockNumber voteEnd;
        bool executed;
        bool canceled;
        address who;
        string url;
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
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    IVotes public immutable _token;

    uint256 private _votingDelay = 0;
    uint256 private _votingPeriod = 1000;
    uint256 private _memberDelegationPercentatge = 10;
    uint256 private _minMemberCountForDelgations = 10;

    mapping(address => address) public _memberToGovWhoApproved;
    uint256 private _memberCount;

    address[] public _governors;
    address immutable _membersContractAddress;

    mapping(uint256 => ProposalVote) private _proposalVotes;
    mapping(uint256 => ProposalCore) private _proposals;
    mapping(address => uint) public _governorsMapping;

    string public _memberMetaURL = "https://www.zini.org/member/";
    string public _metaURL;

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return string.concat(_memberMetaURL, Strings.toString(tokenId));
    }

    constructor(
        address memberAddress,
        address sender,
        string memory tokenName,
        string memory tokenSymbol
    ) {
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
        require(members.balanceOf(msg.sender) > 0, "Not a member");
        _;
    }

    function addGovernor(uint256 propId) public {
        require(
            state(propId) == ProposalState.Succeeded,
            "Invalid Proposal State"
        );

        address newGov = _proposals[propId].who;
        _governors.push(newGov);
        _governorsMapping[newGov] = _governors.length;

        //if is existing member then remove him from member count since he is now part of the governor weight metric
        if (_memberToGovWhoApproved[newGov] != address(0)) {
            _memberCount -= 1;
            _memberToGovWhoApproved[newGov] = address(0);
        }
    }

    function addMember(address newAddress) public onlyGovernor {
        Members members = Members(_membersContractAddress);
        members.mintTo(newAddress);
        _token.assignVoteToken(newAddress);
        _memberCount += 1;
        _memberToGovWhoApproved[newAddress] = msg.sender;
    }

    //members cannot just create proposals.. only governors can do that.. but if a member gets enough delgated votes he can create a proposal
    //he needs a certain _memberDelegationPercentatge and cannot do it with a org that has fewer than 5 members
    function memberHasDelegation(address who) public view returns (bool) {
        require(_memberCount > _minMemberCountForDelgations);
        uint256 numOfVotesForDelegatedStatus = ((100 * _memberCount) / 100);
        require(
            (numOfVotesForDelegatedStatus * _memberDelegationPercentatge) >=
                getVotes(who, block.number - 1)
        );
        return true;
    }

    function getGovWhoApprovedMember(address who)
        public
        view
        returns (address)
    {
        return _memberToGovWhoApproved[who];
    }

    function castVote(uint256 proposalId, uint8 support)
        public
        returns (uint256)
    {
        return _castVote(proposalId, msg.sender, support);
    }

    function propose(
        string memory description,
        PropType pType,
        address who
    ) public returns (uint256) {
        require(
            isGovernor(msg.sender) || memberHasDelegation(msg.sender),
            "Not enough voting power to create proposal"
        );

        uint256 proposalId = hashProposal(pType, keccak256(bytes(description)));

        ProposalCore storage proposal = _proposals[proposalId];

        if (pType == PropType.ADD_GOVERNOR) {
            proposal.who = who;
        }

        if (pType == PropType.REMOVE_GOVERNOR) {
            proposal.who = who;
        }

        require(
            proposal.voteStart.isUnset(),
            "Governor: proposal already exists"
        );

        uint64 snapshot = block.number.toUint64() + votingDelay().toUint64();
        uint64 deadline = snapshot + votingPeriod().toUint64();

        proposal.voteStart.setDeadline(snapshot);
        proposal.voteEnd.setDeadline(deadline);

        return proposalId;
    }

    function isGovernor(address who) public view returns (bool) {
        return (_governorsMapping[who] > 0);
    }

    function setBoardURL(string memory url) public onlyGovernor {
        _metaURL = url;
    }

    function getMemberVotesAddress() public view returns (address) {
        return address(_token);
    }

    function proposalVotes(uint256 proposalId)
        public
        view
        returns (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        )
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (
            proposalVote.againstVotes,
            proposalVote.forVotes,
            proposalVote.abstainVotes
        );
    }

    function hasVoted(uint256 proposalId, address account)
        public
        view
        returns (bool)
    {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    function hashProposal(PropType pType, bytes32 descriptionHash)
        public
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(pType, descriptionHash)));
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

    function proposalSnapshot(uint256 proposalId)
        public
        view
        returns (uint256)
    {
        return _proposals[proposalId].voteStart.getDeadline();
    }

    function proposalDeadline(uint256 proposalId)
        public
        view
        returns (uint256)
    {
        return _proposals[proposalId].voteEnd.getDeadline();
    }

    function votingDelay() public view returns (uint256) {
        return _votingDelay;
    }

    function votingPeriod() public view returns (uint256) {
        return _votingPeriod;
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        returns (uint256)
    {
        return _getVotes(account, blockNumber);
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
        _countVote(proposalId, account, support, weight);

        return weight;
    }

    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return proposalVote.forVotes > proposalVote.againstVotes;
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

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

    function _getVotes(address account, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        return _token.getPastVotes(account, blockNumber);
    }
}

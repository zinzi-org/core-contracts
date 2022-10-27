// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./lib/Strings.sol";
import "./lib/Timers.sol";

import "./Members.sol";
import "./MemberVote.sol";

contract GovernorBoard {
    using Timers for Timers.BlockNumber;

    address immutable _memberAddress;

    enum PropType {
        TEXT_BASED_PROPOSAL,
        ADD_GOVERNOR,
        REMOVE_GOVERNOR,
        SET_BOARD_URL,
        REMOVE_MEMBER,
        REBUKE_MEMBER
    }

    struct ProposalCore {
        Timers.BlockNumber voteStart;
        Timers.BlockNumber voteEnd;
        bool executed;
        bool canceled;
    }

    mapping(uint256 => ProposalCore) private _proposals;

    address[] public _governors;
    mapping(address => uint) public _governorsMapping;

    string public _memberMetaURL = "https://www.zini.org/member/";
    string public _metaURL;

    address immutable _memberVotesAddress;

    uint256 public _proposalThreshold = 10;

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return string.concat(_memberMetaURL, Strings.toString(tokenId));
    }

    constructor(
        address memberAddress,
        address sender,
        string memory tokenName,
        string memory tokenSymbol
    ) {
        _memberAddress = memberAddress;
        _governors.push(sender);
        _governorsMapping[sender] = _governors.length;

        _memberVotesAddress = address(
            new MemberVote(tokenName, tokenSymbol, address(this))
        );

        MemberVote memberVote = MemberVote(_memberVotesAddress);

        memberVote.voteMinterForBoard(sender, _proposalThreshold);
    }

    modifier onlyGovernor() {
        require(_governorsMapping[msg.sender] > 0);
        _;
    }

    function isGovernor(address who) public view returns (bool) {
        return (_governorsMapping[who] > 0);
    }

    function setBoardURL(string memory url) public onlyGovernor {
        _metaURL = url;
    }

    function getMemberVotesAddress() public view returns (address) {
        return _memberVotesAddress;
    }

    //This function can be called by anyone with enough votes to meet the threshold
    function initProposal(
        PropType pType,
        address who,
        address[] memory delegates,
        string memory description
    ) public {
        MemberVote memberVote = MemberVote(_memberVotesAddress);
        if (isGovernor(msg.sender)) {
            require(memberVote.balanceOf(msg.sender) >= _proposalThreshold);
        } else {
            require(getDelegatedVotes(delegates) >= _proposalThreshold);
        }

        if (pType == PropType.ADD_GOVERNOR) {}

        if (pType == PropType.REMOVE_GOVERNOR) {}
    }

    function getDelegatedVotes(address[] memory delegates)
        public
        pure
        returns (uint)
    {
        return 10;
    }
}

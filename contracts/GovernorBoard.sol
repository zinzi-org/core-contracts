// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Members.sol";
import "./lib/Strings.sol";
import "./MemberVote.sol";

contract GovernorBoard {
    address immutable _memberAddress;

    enum PropType {
        ADD_GOVERNOR,
        REMOVE_GOVERNOR
    }

    address[] public _governors;
    mapping(address => uint) public _governorsMapping;

    string public _memberMetaURL = "https://www.zini.org/member/";
    string public _metaURL;

    address public _memberVotesAddress;

    uint256 public _proposalThreshold = 10;

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return string.concat(_memberMetaURL, Strings.toString(tokenId));
    }

    constructor(address memberAddress, address sender) {
        _memberAddress = memberAddress;
        _governors.push(sender);
        _governorsMapping[sender] = _governors.length;

        _memberVotesAddress = address(
            new MemberVote("ZinziDAO", "ZZ", address(this))
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

    function initVote(PropType pType, string memory description) public {
        MemberVote memberVote = MemberVote(_memberVotesAddress);
        require(memberVote.balanceOf(msg.sender) >= _proposalThreshold);
    }

    function initVoteWithDelegates(
        PropType pType,
        address[] memory delegates,
        string memory description
    ) public {}
}

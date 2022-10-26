// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Members.sol";
import "./lib/Strings.sol";
import "./MemberVote.sol";

contract GovernorBoard {
    address immutable _memberAddress;

    address[] public _governors;
    mapping(address => uint) public _governorsMapping;

    string public _memberMetaURL = "https://www.zini.org/member/";
    string public _metaURL;

    address public memberVotes;

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return string.concat(_memberMetaURL, Strings.toString(tokenId));
    }

    constructor(address memberAddress, address sender) {
        _memberAddress = memberAddress;
        _governors.push(sender);
        _governorsMapping[sender] = _governors.length;

        memberVotes = address(new MemberVote("ZinziDAO", "ZZ", address(this)));
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

    function voteToAddGovernor() public {}

    function voteToRemoveGovernor() public {}
}

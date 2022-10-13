// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Member.sol";
import "./lib/Strings.sol";

contract MemberBoard {
    address immutable _memberAddress;

    address[3] public _boardMembers;
    mapping(uint256 => uint256[]) _votesAgainst;

    string public _memberMetaURL = "https://www.zini.org/member/";
    string public _metaURL;

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return string.concat(_memberMetaURL, Strings.toString(tokenId));
    }

    constructor(address memberAddress, address sender) {
        _memberAddress = memberAddress;
        _boardMembers[0] = sender;
    }

    modifier onlyBoardMember() {
        require(
            msg.sender == _boardMembers[0] ||
                msg.sender == _boardMembers[1] ||
                msg.sender == _boardMembers[2]
        );
        _;
    }

    function isBoardMember(address who) public view returns (bool) {
        return (who == _boardMembers[0] ||
            who == _boardMembers[1] ||
            who == _boardMembers[2]);
    }

    function setBoardURL(string memory url) public onlyBoardMember {
        _metaURL = url;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Member.sol";
import "./lib/Strings.sol";

contract MemberBoard {
    address immutable _memberAddress;

    address public _governor;

    string public _memberMetaURL = "https://www.zini.org/member/";
    string public _metaURL;

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return string.concat(_memberMetaURL, Strings.toString(tokenId));
    }

    constructor(address memberAddress, address sender) {
        _memberAddress = memberAddress;
        _governor = sender;
    }

    modifier onlyGovernor() {
        require(msg.sender == _governor);
        _;
    }

    function isGovernor(address who) public view returns (bool) {
        return (who == _governor);
    }

    function setBoardURL(string memory url) public onlyGovernor {
        _metaURL = url;
    }
}

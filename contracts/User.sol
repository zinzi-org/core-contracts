// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./lib/Strings.sol";
import "./Member.sol";

contract User {
    address immutable _memberAddress;
    string public _publicName;
    string public _publicEmail;
    string public _publicURL;
    address public _publicWalletAddress;
    uint256 immutable _tokenId;
    string public _metaURL;

    constructor(address memberAddress, uint256 tokenId) {
        _memberAddress = memberAddress;
        _tokenId = tokenId;
    }

    modifier onlyOwner() {
        Member mem = Member(_memberAddress);
        require(msg.sender == mem.ownerOf(_tokenId), "Not the owner");
        _;
    }

    function setPublicName(string memory name) public onlyOwner {
        _publicName = name;
    }

    function setPublicEmail(string memory email) public onlyOwner {
        _publicEmail = email;
    }

    function setPublicURL(string memory url) public onlyOwner {
        _publicURL = url;
    }

    function setPublicWalletAddress(address walletAddress) public onlyOwner {
        _publicWalletAddress = walletAddress;
    }

    function setMetaURL(string memory url) public onlyOwner {
        _metaURL = url;
    }

    function getTokenId() public view returns (uint256) {
        return _tokenId;
    }
}

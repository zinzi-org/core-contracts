// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./MemberBoard.sol";
import "./MemberNFT.sol";

contract MemberBoardFactory {
    mapping(address => string) public names;
    mapping(address => bool) public boards;
    address public memberNFTAddress;

    constructor() {
        memberNFTAddress = address(new Member());
    }

    function create(string memory newBoardName) public {
        address boardAddress = address(new MemberBoard());
        names[boardAddress] = newBoardName;
        boards[boardAddress] = true;
        Member f = Member(memberNFTAddress);
        f.mintToFirst(msg.sender, boardAddress);
    }

    function isBoard(address who) public view returns (bool) {
        return boards[who];
    }
}

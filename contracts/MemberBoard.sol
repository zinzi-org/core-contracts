// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MemberBoard {
    address public memberOne;
    address public memberTwo;
    address public memberThree;

    address[] public applicantList;
    mapping(address => address[]) applicantVotes;
    mapping(address => int256) applicantPoints;
    mapping(address => bool) activeApplicants;

    string public URL;
    string public METAURL;

    function isBoardMember(address who) public view returns (bool) {
        return (who == memberOne || who == memberTwo || who == memberThree);
    }

    function getApplicants() public view returns (address[] memory) {
        return applicantList;
    }

    function createApplicant() public payable {
        require(!activeApplicants[msg.sender], "Already active applicant");
        require(applicantPoints[msg.sender] > -3, "account rejected");
        activeApplicants[msg.sender] = true;
        applicantList.push(msg.sender);
    }

    function voteForApplicant(address applicant) public {
        require(activeApplicants[applicant], "Not a applicant");
        bool didVote = false;
        for (uint256 i = 0; i < applicantVotes[applicant].length; i++) {
            if (applicantVotes[applicant][i] == msg.sender) {
                didVote = true;
            }
        }
        require(!didVote, "Sender already voted");
        applicantVotes[applicant].push(msg.sender);
        applicantPoints[applicant] += 1;
    }

    function getApplicantVoteCount(address applicant)
        public
        view
        returns (uint256)
    {
        return applicantVotes[applicant].length;
    }

    function approveApplicant(address applicant) public {
        _burnApplicant(applicant);
        delete applicantVotes[msg.sender];
    }

    function rejectApplicant(address applicant) public {
        require(activeApplicants[applicant], "Invalid applicant address");
        activeApplicants[applicant] = false;
        applicantPoints[msg.sender] -= 1;
        _burnApplicant(applicant);
        delete applicantVotes[msg.sender];
    }

    function _burnApplicant(address applicant) internal {
        uint256 index = 0;
        for (index = 0; index < applicantList.length; index++) {
            if (applicantList[index] == applicant) {
                break;
            }
        }
        applicantList[index] = applicantList[applicantList.length - 1];
        applicantList.pop();
    }
}

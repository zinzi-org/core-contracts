// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.17;

contract Member {
    address private _ownerAddress;
    uint256 private _memberTokenId;
    string private _displayName;
    string private _bio;
    string private _avatar;
    string private _website;
    string private _twitter;
    string private _github;
    string private _linkedin;
    string private _telegram;
    string private _discord;
    string private _email;
    string private _location;
    string private _pronouns;
    string private _skills;
    string private _interests;
    string private _experience;
    string private _education;
    string private _metaURI;

    constructor(address ownerAddress, uint256 memberTokenId) {
        _ownerAddress = ownerAddress;
        _memberTokenId = memberTokenId;
    }

    modifier onlyOwner() {
        require(msg.sender == _ownerAddress, "Only owner can call this function");
        _;
    }

    function setDisplayName(string memory displayName) onlyOwner public {
        _displayName = displayName;
    }

    function setBio(string memory bio) onlyOwner public {
        _bio = bio;
    }

    function setAvatar(string memory avatar) onlyOwner public {
        _avatar = avatar;
    }

    function setWebsite(string memory website) onlyOwner public {
        _website = website;
    }

    function setTwitter(string memory twitter) onlyOwner public {
        _twitter = twitter;
    }

    function setGithub(string memory github) onlyOwner public {
        _github = github;
    }

    function setLinkedin(string memory linkedin) onlyOwner public {
        _linkedin = linkedin;
    }

    function setTelegram(string memory telegram) onlyOwner public {
        _telegram = telegram;
    }

    function setDiscord(string memory discord) onlyOwner public {
        _discord = discord;
    }


    function setEmail(string memory email) onlyOwner public {
        _email = email;
    }

    function setLocation(string memory location) onlyOwner public {
        _location = location;
    }

    function setPronouns(string memory pronouns) onlyOwner public {
        _pronouns = pronouns;
    }

    function setSkills(string memory skills) onlyOwner public {
        _skills = skills;
    }


    function setInterests(string memory interests) onlyOwner public {
        _interests = interests;
    }

    function setExperience(string memory experience) onlyOwner public {
        _experience = experience;
    }

    function setEducation(string memory education) onlyOwner public {
        _education = education;
    }

    function getDisplayName() public view returns (string memory) {
        return _displayName;
    }

    function getBio() public view returns (string memory) {
        return _bio;
    }

    function getAvatar() public view returns (string memory) {
        return _avatar;
    }

    function getWebsite() public view returns (string memory) {
        return _website;
    }

    function getTwitter() public view returns (string memory) {
        return _twitter;
    }

    function getGithub() public view returns (string memory) {
        return _github;
    }

    function getLinkedin() public view returns (string memory) {
        return _linkedin;
    }

    function getTelegram() public view returns (string memory) {
        return _telegram;
    }

    function getDiscord() public view returns (string memory) {
        return _discord;
    }

    function getEmail() public view returns (string memory) {
        return _email;
    }

    function getLocation() public view returns (string memory) {
        return _location;
    }

    function getPronouns() public view returns (string memory) {
        return _pronouns;
    }

    function getSkills() public view returns (string memory) {
        return _skills;
    }

    function getInterests() public view returns (string memory) {
        return _interests;
    }

    function getExperience() public view returns (string memory) {
        return _experience;
    }

    function getEducation() public view returns (string memory) {
        return _education;
    }

    function getOwnerAddress() public view returns (address) {
        return _ownerAddress;
    }

    function getMemberTokenId() public view returns (uint256) {
        return _memberTokenId;
    }

    function setMetaURI(string memory metaURI) onlyOwner public {
        _metaURI = metaURI;
    }

    function getMetaURI() public view returns (string memory) {
        return _metaURI;
    }

    


}
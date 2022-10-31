const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, should } = require("chai");
const { ethers } = require("hardhat");

const memberCompiled = require("../artifacts/contracts/Members.sol/Members.json");
const memberBoardCompiled = require("../artifacts/contracts/GovernorBoard.sol/GovernorBoard.json");
const memberVotesCompiled = require("../artifacts/contracts/MemberVote.sol/MemberVote.json");

describe("Base Test Setup", () => {

    async function fixture() {
        const [owner, otherAccount] = await ethers.getSigners();
        const BoardFactory = await ethers.getContractFactory("GovernorBoardFactory");
        const factory = await BoardFactory.deploy();
        var memberAddress = await factory.membersAddress();
        const memberContract = new ethers.Contract(memberAddress, memberCompiled.abi, owner);
        return { factory, memberContract, owner, otherAccount };
    }

    it('has board member factory with member board', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        var symbol = await memberContract.symbol();
        expect(symbol).to.equal("MM");
        expect(await factory.create("ZinziDAO", "ZZ")).to.emit(factory, "BoardCreated").withArgs(anyValue);
        var balance = await memberContract.balanceOf(owner.address);
        expect(balance).to.equal(1);
        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(0);
        var uri = await memberContract.tokenURI(balance);
        expect(uri).to.equal("https://www.zini.org/member/1");
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        expect(memberBoard.address).to.not.be.null;
        var metaURL = await memberBoard._memberMetaURL();
        expect(metaURL).to.equal("https://www.zini.org/member/");
        var isBoardMember = await memberBoard.isGovernor(owner.address);
        expect(isBoardMember).to.eq(true);
    });

    it('can add member to group', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create("ZinziDAO", "ZZ");
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        await memberBoard.addMember(otherAccount.address);
        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(1);
    });

    it('can add member to group', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create("ZinziDAO", "ZZ");
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        await memberBoard.addMember(otherAccount.address);
        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(1);
    });

    it('governor can create proposal', async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create("ZinziDAO", "ZZ");
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        await memberBoard.addMember(otherAccount.address);
        const options = { gasLimit: 1000000 };
        await memberBoard.propose("test text", 0, ethers.constants.AddressZero, options);
        const memberVotesAddress = memberBoard.getMemberVotesAddress();
        const memberVotes = new ethers.Contract(memberVotesAddress, memberVotesCompiled.abi, owner);
        var newMemberVoteBalance = await memberVotes.balanceOf(otherAccount.address);
        expect(newMemberVoteBalance).to.equal(1);
    });

    it("member cannot create proposal without delegation", async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create("ZinziDAO", "ZZ");
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);
        const memberBoardOther = new ethers.Contract(groupId, memberBoardCompiled.abi, otherAccount);
        await memberBoard.addMember(otherAccount.address);
        const options = { gasLimit: 1000000 };
        await expect(memberBoardOther.propose("test text", 0, ethers.constants.AddressZero, options))
            .to.be.revertedWith("Member does not have a delegation");
    });

    it("member can create proposal with delegation", async () => {
        const { factory, memberContract, owner, otherAccount } = await loadFixture(fixture);
        await factory.create("ZinziDAO", "ZZ");
        var balance = await memberContract.balanceOf(owner.address);
        var groupId = await memberContract.getTokenGroup(balance);
        const memberBoard = new ethers.Contract(groupId, memberBoardCompiled.abi, owner);

        await memberBoard.addMember(otherAccount.address);
        const signers = [];

        for (let i = 0; i < 15; i++) {
            wallet = ethers.Wallet.createRandom();
            wallet = wallet.connect(ethers.provider);
            await owner.sendTransaction({ to: wallet.address, value: ethers.utils.parseEther(".5") });
            signers.push(wallet);
        }

        const memberVotesAddress = await memberBoard.getMemberVotesAddress();
        const options = { gasLimit: 1000000 };

        for (var i = 0; i < 15; i++) {
            await memberBoard.addMember(signers[i].address);
        }

        for (var i = 0; i < 4; i++) {
            const memberVotes = new ethers.Contract(memberVotesAddress, memberVotesCompiled.abi, signers[i]);
            await memberVotes.delegate(otherAccount.address, options);
        }

        const memberBoardOther = new ethers.Contract(groupId, memberBoardCompiled.abi, otherAccount);
        await memberBoardOther.propose("test text", 0, ethers.constants.AddressZero, options);
    });


});

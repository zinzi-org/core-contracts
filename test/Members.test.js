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
const projectCompiled = require('../artifacts/contracts/Project.sol/Project.json');

describe("Base Test Cases", () => {

    async function fixture() {
        const [owner, otherAccount] = await ethers.getSigners();
        const options = { gasLimit: 1000000 };
        const boardFactoryFactory = await ethers.getContractFactory("GovernorBoardFactory");
        const factory = await boardFactoryFactory.deploy();
        var memberAddress = await factory.membersAddress();
        var projectAddress = await factory.projectAddress();
        var projectInstance = new ethers.Contract(projectAddress, projectCompiled.abi, owner);
        const memberContract = new ethers.Contract(memberAddress, memberCompiled.abi, owner);
        await factory.create("ZinziDAO", "ZZ");
        var usersTokens = await memberContract.getBoards(owner.address);
        var boardAddress = await memberContract.getBoardForToken(usersTokens[0])
        const memberBoard = new ethers.Contract(boardAddress, memberBoardCompiled.abi, owner);
        await memberBoard.addMember(otherAccount.address);

        const signers = [];
        for (let i = 0; i < 15; i++) {
            wallet = ethers.Wallet.createRandom();
            wallet = wallet.connect(ethers.provider);
            await owner.sendTransaction({ to: wallet.address, value: ethers.utils.parseEther(".5") });
            signers.push(wallet);
            memberBoard.addMember(wallet.address);
        }
        return { memberContract, memberBoard, owner, otherAccount, signers, options, projectInstance };
    }

    it('has board member factory with member board', async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options } = await loadFixture(fixture);
        expect(memberBoard.address).to.not.be.null;
        var metaURL = await memberBoard._memberMetaURL();
        expect(metaURL).to.equal("https://www.zini.org/member/");
        var isBoardMember = await memberBoard.isGovernor(owner.address);
        expect(isBoardMember).to.eq(true);
    });

    it('can add member to group', async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options } = await loadFixture(fixture);
        var obalance = await memberContract.balanceOf(otherAccount.address);
        expect(obalance).to.equal(1);
    });

    it('governor can create proposal', async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options } = await loadFixture(fixture);
        await memberBoard.propose("test text", 0, ethers.constants.AddressZero, options);
        const memberVotesAddress = memberBoard.getMemberVotesAddress();
        const memberVotes = new ethers.Contract(memberVotesAddress, memberVotesCompiled.abi, owner);
        var newMemberVoteBalance = await memberVotes.balanceOf(otherAccount.address);
        expect(newMemberVoteBalance).to.equal(1);
    });

    it("member cannot create proposal without delegation", async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options } = await loadFixture(fixture);
        const memberBoardOther = new ethers.Contract(memberBoard.address, memberBoardCompiled.abi, otherAccount);
        await expect(memberBoardOther.propose("test text", 0, ethers.constants.AddressZero, options))
            .to.be.revertedWith("Member does not have a delegation");
    });

    it("member can create proposal with delegation", async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options } = await loadFixture(fixture);
        const memberVotesAddress = await memberBoard.getMemberVotesAddress();
        for (var i = 0; i < 4; i++) {
            const memberVotes = new ethers.Contract(memberVotesAddress, memberVotesCompiled.abi, signers[i]);
            var vd = await memberVotes.delegate(otherAccount.address, options);
            vd.wait();
        }
        const memberBoardOther = new ethers.Contract(memberBoard.address, memberBoardCompiled.abi, otherAccount);
        await memberBoardOther.propose("test text", 0, ethers.constants.AddressZero, options);
    });


    //here we will have 5 signers who are board members delegate their vote to a member..
    //after a member has enough delegates he will be able to create a proposal
    //we will then create a proposal to give member governor status
    //we will run a vote and check the results to ensure the vote won
    // 6 - for votes
    // 9 - abstain votes
    // Proposal State - Success
    it("Propose new governor with delegation", async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options } = await loadFixture(fixture);
        const memberVotesAddress = await memberBoard.getMemberVotesAddress();

        for (var i = 0; i < 5; i++) {
            const memberVotes = new ethers.Contract(memberVotesAddress, memberVotesCompiled.abi, signers[i]);
            await memberVotes.delegate(otherAccount.address, options);
        }

        var memberBoardOtherAccount = memberBoard.connect(otherAccount);
        var proposalTx = await memberBoardOtherAccount.propose("Proposal to Add Governor", 1, otherAccount.address, options);
        const rc = await proposalTx.wait(); // 0ms, as tx is already confirmed
        const event = rc.events.find(event => event.event === 'Proposal');
        const [proposalId] = event.args;

        for (let i = 0; i < 15; i++) {
            var memberBoardOther = memberBoard.connect(signers[i]);
            var bn = await ethers.provider.getBlockNumber();
            var votesN = await memberBoardOther.getVotes(signers[i].address, (bn - 1))
            if (votesN > 0) {
                var otherBoardTx = await memberBoardOther.castVote(proposalId, 2, options);
                otherBoardTx.wait();
            }
        }

        var otherAcTx = await memberBoardOtherAccount.castVote(proposalId, 1, options);
        otherAcTx.wait();

        var votes = await memberBoardOtherAccount.proposalVotes(proposalId);

        expect(votes.abstainVotes).to.equal(9);
        expect(votes.forVotes).to.equal(6);

        for (let index = 0; index < 1000; index++) {
            await ethers.provider.send('evm_mine');
        }

        var propState = await memberBoard.state(proposalId);

        expect(propState).to.equal(4);

        var addGovPropTx = await memberBoard.addGovernor(proposalId, options);
        addGovPropTx.wait();

        var isGov = await memberBoard.isGovernor(otherAccount.address);

        expect(isGov).to.be.true;
    });

    it("can create a board, add a member and create a project", async () => {
        const { memberContract, memberBoard, owner, otherAccount, signers, options, projectInstance } = await loadFixture(fixture);
        const memberVotesAddress = await memberBoard.getMemberVotesAddress();
        // string memory nameP,
        // string memory summary,
        // Workflow flow,
        // Funding funding
        projectInstance.mintProject("Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore",
            0,
            1,
            10000000
        );




    });

});

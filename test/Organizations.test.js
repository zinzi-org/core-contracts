const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, should } = require("chai");
const { ethers } = require("hardhat");


describe("Gov Org Test Cases", () => {

    async function fixture() {

        const [...signers] = await ethers.getSigners();

        let boardFactoryFactory = await ethers.getContractFactory("GovernorBoardFactory");
        let factoryContract = await boardFactoryFactory.deploy();
        factoryContract = factoryContract.connect(signers[0]);
        var membersAddress = await factoryContract.membersAddress();
      
        let membersFactory = await ethers.getContractFactory("Members");
        let membersContract = membersFactory.attach(membersAddress);
        membersContract = membersContract.connect(signers[0]);
  
        await factoryContract.create("ZinziDAO", "ZZ");
        var usersTokens = await membersContract.getBoards(signers[0].address);
        var boardAddress = await membersContract.getBoardForToken(usersTokens[0]);
     
        let boardFactory = await ethers.getContractFactory("GovernorBoard");
        let boardContract = boardFactory.attach(boardAddress);
        boardContract = boardContract.connect(signers[0]);
        
        let memberVotesAddress = await boardContract.getMemberVotesAddress();
        let memberVotesFactory = await ethers.getContractFactory("MemberVote");
        let memberVotesContract = memberVotesFactory.attach(memberVotesAddress);
        memberVotesContract = memberVotesContract.connect(signers[0]);
        
        for (var i = 1; i < signers.length; i++) {
            await boardContract.addMember(signers[i].address);
        }

        return { factoryContract, membersContract, boardContract, memberVotesContract, signers };
    }

    it('has board member factory with member board', async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, signers } = await loadFixture(fixture);

        expect(boardContract.address).to.not.be.null;
        var isBoardMember = await boardContract.isGovernor(signers[0].address);
        expect(isBoardMember).to.eq(true);
    });

    it('can add member to group', async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, signers } = await loadFixture(fixture);

        var obalance = await membersContract.balanceOf(signers[1].address);
        expect(obalance).to.equal(1);
    });

    it('governor can create proposal', async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, signers } = await loadFixture(fixture);

        let tx = await boardContract.propose.populateTransaction("test text", 0, ethers.ZeroAddress, 0, 10);
        let gasEstimate = await ethers.provider.estimateGas(tx);
        tx.gasLimit = gasEstimate;
        let txResponse = await signers[0].sendTransaction(tx);
        let receipt = await txResponse.wait();

        var newMemberVoteBalance = await memberVotesContract.balanceOf(signers[1].address);
        expect(newMemberVoteBalance).to.equal(1);
    });

    it("member cannot create proposal without delegation", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, signers } = await loadFixture(fixture);

        let boardContractInst = boardContract.connect(signers[1]);
        let tx = await boardContractInst.propose.populateTransaction("test text", 0, signers[1].address, 0, 0);
        tx.gasLimit = 100000;
        await expect(signers[1].sendTransaction(tx)).to.be.revertedWith("Not enough voting power to create proposal");
    });

    it("member can create proposal with delegation", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, signers } = await loadFixture(fixture);

        for (var i = 2; i < 6; i++) {
            let memberVotesContractInst = memberVotesContract.connect(signers[i]);

            let tx = await memberVotesContractInst.delegate.populateTransaction(signers[1].address);
            let gasEstimate = await ethers.provider.estimateGas(tx);
            tx.gasLimit = gasEstimate;
            let txResponse = await signers[i].sendTransaction(tx);
            await txResponse.wait();
        }

        let boardContractInst = boardContract.connect(signers[1]);
        let txp = await boardContractInst.propose.populateTransaction("test text", 0, signers[1].address , 0, 0);

        let txResponsep = await signers[1].sendTransaction(txp);
        await txResponsep.wait();
    });


    //here we will have 5 signers who are board members delegate their vote to a member..
    //after a member has enough delegates he will be able to create a proposal
    //we will then create a proposal to give member governor status
    //we will run a vote and check the results to ensure the vote won
    // 6 - for votes
    // 10 - abstain votes
    // Proposal State - Success
    it("Propose new governor with delegation", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, signers } = await loadFixture(fixture);

        for (var i = 2; i < 7; i++) {
            let memberVotesContractInst = memberVotesContract.connect(signers[i]);
            let tx = await memberVotesContractInst.delegate.populateTransaction(signers[1].address);
            let gasEstimate = await ethers.provider.estimateGas(tx);
            tx.gasLimit = gasEstimate;
            let txResponse = await signers[i].sendTransaction(tx);
            await txResponse.wait();
        }

        let boardContractInst = boardContract.connect(signers[1]);

        let proposalTx = await boardContractInst.propose.populateTransaction("Proposal to Add Governor", 1, signers[1].address, 0, 0);
        let gasEstimate = await boardContractInst.propose.estimateGas("Proposal to Add Governor", 1, signers[1].address, 0, 0);
        proposalTx.gasLimit = gasEstimate;
       
        let proposalTxReal = await boardContractInst.propose("Proposal to Add Governor", 1, signers[1].address, 0, 0, { gasLimit: gasEstimate.value });   
        const rc = await proposalTxReal.wait();

        const proposalId = rc.logs[0].args[0]

        for (let i = 2; i < 17; i++) {
            boardContractInst = boardContractInst.connect(signers[i]);
            var bn = await ethers.provider.getBlockNumber();
            var votesN = await boardContractInst.getVotes(signers[i].address, (bn - 1))
            if (votesN > 0) {
                let tx = await boardContractInst.castVote.populateTransaction(proposalId, 2);
                let gasEstimate = await ethers.provider.estimateGas(tx);
                tx.gasLimit = gasEstimate;
                let txResponse = await signers[i].sendTransaction(tx);
                await txResponse.wait();
            }
        }

        boardContractInst = boardContractInst.connect(signers[1]);

        var otherAcTx = await boardContractInst.castVote.populateTransaction(proposalId, 1);
        let txResponseOther = await signers[1].sendTransaction(otherAcTx);
        await txResponseOther.wait();

        var votes = await boardContractInst.proposalVotes(proposalId);

        expect(votes.abstainVotes).to.equal(10);
        expect(votes.forVotes).to.equal(6);

        for (let index = 0; index < 10000; index++) {
            await ethers.provider.send('evm_mine');
        }

        var propState = await boardContractInst.state(proposalId);

        expect(propState).to.equal(4);

        var addGovPropTx = await boardContractInst.addGovernor.populateTransaction(proposalId);
        let gasEstimateAddGov = await ethers.provider.estimateGas(addGovPropTx);
        addGovPropTx.gasLimit = gasEstimateAddGov;
        let txResponseAddGov = await signers[1].sendTransaction(addGovPropTx);
        await txResponseAddGov.wait();

        var isGov = await boardContractInst.isGovernor(signers[1].address);

        expect(isGov).to.be.true;
    });



});

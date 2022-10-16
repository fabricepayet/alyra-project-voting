// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    struct Proposal {
        string description;
        uint256 voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress);

    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );

    event ProposalRegistered(uint256 proposalId);

    event Voted(address voter, uint256 proposalId);

    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    WorkflowStatus public currentWorkflowStatus;
    address[] public votersAddresses;

    modifier mustBeRegistered() {
        require(
            voters[msg.sender].isRegistered == true,
            "You must be registered"
        );
        _;
    }

    modifier mustBeOnSpecificStep(WorkflowStatus _requiredWorkflowStatus) {
        require(
            currentWorkflowStatus == _requiredWorkflowStatus,
            "Not authorized in the current workflow state"
        );
        _;
    }

    modifier mustNotHaveVotedBefore() {
        require(voters[msg.sender].hasVoted == false, "You have already voted");
        _;
    }

    modifier proposalMustExist(uint256 _proposalId) {
        require(proposals.length - 1 >= _proposalId, "The proposal must exist");
        _;
    }

    constructor() {
        currentWorkflowStatus = WorkflowStatus.RegisteringVoters;
    }

    function registerVoters(address[] calldata _voters)
        external
        onlyOwner
        mustBeOnSpecificStep(WorkflowStatus.RegisteringVoters)
    {
        votersAddresses = _voters;
        for (uint256 i = 0; i < _voters.length; i++) {
            voters[_voters[i]] = Voter(true, false, 0);
            emit VoterRegistered(_voters[i]);
        }
    }

    function registerProposal(string calldata _description)
        external
        mustBeRegistered
        mustBeOnSpecificStep(WorkflowStatus.ProposalsRegistrationStarted)
    {
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    function voteForAProposal(uint256 _proposalId)
        external
        mustBeRegistered
        mustNotHaveVotedBefore
        mustBeOnSpecificStep(WorkflowStatus.VotingSessionStarted)
        proposalMustExist(_proposalId)
    {
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        // In my first version the voteCount was increment below, it is more simple and that allow to remove the array of voters' addresses and the countTheVotes function.
        // In consideration, it costs more gas for the voter. I changed my code after re-reading the project's instructions.
        // proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function getWinner()
        external
        view
        mustBeOnSpecificStep(WorkflowStatus.VotesTallied)
        returns (Proposal memory)
    {
        Proposal memory winningProposal;
        uint256 nbProposalsWithSameVoteCount = 0;

        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningProposal.voteCount) {
                winningProposal = proposals[i];
                nbProposalsWithSameVoteCount = 0;
            } else if (proposals[i].voteCount == winningProposal.voteCount) {
                nbProposalsWithSameVoteCount++;
            }
        }

        require(
            nbProposalsWithSameVoteCount == 0,
            "No winning proposal, many proposals have the highest number of votes"
        );

        return winningProposal;
    }

    function countTheVotes() private onlyOwner {
        for (uint256 i = 0; i < votersAddresses.length; i++) {
            if (voters[votersAddresses[i]].hasVoted == true) {
                proposals[voters[votersAddresses[i]].votedProposalId]
                    .voteCount++;
            }
        }
    }

    function changeWorkflowStep(WorkflowStatus _newStatus) private onlyOwner {
        emit WorkflowStatusChange(currentWorkflowStatus, _newStatus);
        currentWorkflowStatus = _newStatus;
    }

    function nextWorkflowStep() external onlyOwner {
        if (currentWorkflowStatus == WorkflowStatus.RegisteringVoters) {
            changeWorkflowStep(WorkflowStatus.ProposalsRegistrationStarted);
        } else if (
            currentWorkflowStatus == WorkflowStatus.ProposalsRegistrationStarted
        ) {
            changeWorkflowStep(WorkflowStatus.ProposalsRegistrationEnded);
        } else if (
            currentWorkflowStatus == WorkflowStatus.ProposalsRegistrationEnded
        ) {
            changeWorkflowStep(WorkflowStatus.VotingSessionStarted);
        } else if (
            currentWorkflowStatus == WorkflowStatus.VotingSessionStarted
        ) {
            changeWorkflowStep(WorkflowStatus.VotingSessionEnded);
        } else if (currentWorkflowStatus == WorkflowStatus.VotingSessionEnded) {
            countTheVotes();
            changeWorkflowStep(WorkflowStatus.VotesTallied);
        } else {
            revert("The voting is over. No more steps.");
        }
    }
}

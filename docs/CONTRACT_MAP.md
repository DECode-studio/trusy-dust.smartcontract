Contracts and responsibilities (1 paragraph each):
- DustToken: ERC20 points with open mint/burn (wire role checks externally); used for fees and rewards.
- Identity: stores User struct (trustScore, tier, reputation, posts, jobsCompleted, hasBadge) per address.
- Core: reward service; `rewardSocial` and `rewardJob` add trustScore and mint DUST; updates Identity counters.
- Content: post flow; `mintPost` burns 10 DUST and increments user posts.
- Jobs: job lifecycle; `createJob` burns 10 DUST; approve/cancel with statuses OPEN/COMPLETED/CANCELLED; approve triggers Core.rewardJob.
- Verifier: wrapper to external verifier; on success, updates tier in Identity.
- SharedTypes: enums (SocialAction, JobStatus) and structs (User, Job).
- Errors: shared custom errors.

Main functions, 1 sentence each:
- DustToken.mint/burn: anyone can call in this skeleton (intended for integration with access control).
- Identity.addTrust/setTier/addReputation/addPost/addJobCompleted: update user fields.
- Core.rewardSocial: rewards social actions (LIKE/COMMENT/REPOST) with trust/DUST.
- Core.rewardJob: rewards job completion based on rating (20e18–200e18 DUST).
- Content.mintPost: user burns 10 DUST to record a post.
- Jobs.createJob: user burns 10 DUST to open a job with minScore.
- Jobs.approveJob/cancelJob: manage job status; approve calls Core.rewardJob.
- Verifier.setVerifiers: set verifier addresses.
- Verifier.verifyTrustScore/verifyTier: check proofs and optionally set tier in Identity.

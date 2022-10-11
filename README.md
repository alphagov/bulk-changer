# Dependabot PR Sync

Several `alphagov` repositories contain pull request templates, to warn requesters about things like the fact that the repo is continuously deployed, that the repo requires manual pre- or post- merge steps, or that the repo lacks an automated test suite.

The pull requests that Dependabot raises do not use these templates, which has led to issues in the past where reviewers have assumed that a Dependabot PR was safe to merge, when it was not.

This repo contains a script that will find every GOV.UK repo that contains a pull request template, and will automatically raise a PR to add a GitHub Actions workflow[^workflow] that will post the pull request description as a comment on each pull request that Dependabot raises.

To run the script (this requires a GitHub API token with the `workflow` scope):

`GITHUB_TOKEN="..." bundle exec rake raise_prs`

To run the test suite:

`bundle exec rake`

[^workflow]: https://github.com/robinjam/dependabot-pr-sync/blob/main/copy-pr-template-to-dependabot-prs.yaml

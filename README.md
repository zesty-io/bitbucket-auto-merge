# BitBucket Auto Merge

Use BitBucket's API to automatically create and merge pull requests. This is useful for triggering build processes from CMS webhooks. 

Required arguments:
* `-s | --source`           Source git branch to create pull request from.
* `-d | --destination`      Destination git branch to merge pull request to.

Optional arguments:
* `-u | --user`             BitBucket username. If not set, uses BITBUCKET_AUTOMERGE_USER.
* `-p | --password`         BitBucket user password. If not set, uses BITBUCKET_AUTOMERGE_PASS.
* `--repo-owner`       The repository owner. If not set, uses BITBUCKET_REPO_OWNER.
* `--repo-slug`        The slug of the repository. If not set, uses BITBUCKET_REPO_SLUG.
* `--version`        Display the version of this script

Requirements:
*    `curl` for making network requests with options.
*    `jq`  for reading JSON data.

## Examples:
Create and automatically merge a pull request from AUTO_MERGE to qa:
```
# Merge master into develop
./script.sh -s AUTO_MERGE -d qa
```

All options:
```
script.sh -s AUTO_MERGE -d qa -u sunsbot -p xyzxyz --repo-owner NBAFrontEndDev --repo-slug nba-teams-static-suns
``` 

## Setup and Usage

To use, create a branch in your repository called "AUTO_MERGE", create a file on that branch called auto_merge. Setup your user or a new user with write/merge access to the repository. Generate an app password for that user https://bitbucket.org/account/settings/app-passwords/

Create a post request 

```
curl --location --request POST 'http://localhost:8080/' \
--header 'Authorization: Bearer APP_PASSWORD' \
--header 'Content-Type: application/json' \
--data-raw '{
    "RepoSourceBranch" : "AUTO_MERGE",
    "RepoTargetBranch" : "qa",
    "RepoName" : "nba-teams-static-suns",
    "RepoUser" : "NBAFrontEndDev",
    "BitbucketUser" : "sunsbot"
}'
```


## Local Dev and Testing

1. Edit invoke.go or bitbucket-auto-merge.sh
2. docker build . (when complete, this outputs an image hash like sha:01010101....., copy for next line)
3. docker run -dp 8080:8080 -it sha:01010101.....
4. Run post request in to localhost 

### Example local post request test

Authentication: Bearer [bitbucket password]
Post Body
```
{
    "RepoSourceBranch" : "AUTO_MERGE",
    "RepoTargetBranch" : "qa",
    "RepoName" : "nba-teams-static-suns",
    "RepoUser" : "NBAFrontEndDev",
    "BitbucketUser" : "sunsbot"
}
```
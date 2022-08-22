#!/usr/bin/env bash

# Setup default values for variables
VERSION="1.0.0"
BB_PR_SOURCE=AUTO_MERGE
BB_PR_DESTINATION=
BB_USER=sunsbot
BB_PASSWORD=
BB_REPO_OWNER=
BB_REPO_SLUG=
CURL_BIN=$(which curl)
JQ_BIN=$(which jq)

function usage() {
    cat <<EOM
Required arguments:
    -s | --source           Source git branch to create pull request from.
    -d | --destination      Destination git branch to merge pull request to.

Optional arguments:
    -u | --user             BitBucket username. If not set, uses BITBUCKET_AUTOMERGE_USER.
    -p | --password         BitBucket user password. If not set, uses BITBUCKET_AUTOMERGE_PASS.
         --repo-owner       The repository owner. If not set, uses BITBUCKET_REPO_OWNER.
         --repo-slug        The slug of the repository. If not set, uses BITBUCKET_REPO_SLUG.
         --version          Display the version of this script

Examples:
  Create and automatically merge a pull request from master to develop:

    script.sh -s AUTO_MERGE -d qa

  All options:

    script.sh -s AUTO_MERGE -d qa -u sunsbot -p xyz --repo-owner NBAFrontEndDev --repo-slug nba-teams-static-suns

EOM

    exit 3
}

# Check requirements
function require() {
    command -v "$1" > /dev/null 2>&1 || {
        echo "Some of the required software is not installed:"
        echo "    please install $1" >&2;
        exit 4;
    }
}

function assertRequiredArgumentsSet() {

    if [ -z ${BITBUCKET_AUTOMERGE_USER+x} ];
      then unset BITBUCKET_AUTOMERGE_USER
      else
        BB_USER=$BITBUCKET_AUTOMERGE_USER
    fi

    if [ -z ${BITBUCKET_AUTOMERGE_PASS+x} ];
      then unset BITBUCKET_AUTOMERGE_PASS
      else
        BB_PASSWORD=$BITBUCKET_AUTOMERGE_PASS
    fi
    
    if [ -z ${BITBUCKET_REPO_OWNER+x} ];
      then unset BITBUCKET_REPO_OWNER
      else
        BB_REPO_OWNER=$BITBUCKET_REPO_OWNER
    fi

    if [ -z ${BITBUCKET_REPO_SLUG+x} ];
      then unset BITBUCKET_REPO_SLUG
      else
        BB_REPO_SLUG=$BITBUCKET_REPO_SLUG
    fi

    if [ BB_PR_SOURCE == false ]; then
        echo "Source is required. You can pass the value using -s, --source"
        exit 7
    fi

    if [ BB_PR_DESTINATION == false ]; then
        echo "Destination is required. You can pass the value using -d, --destination"
        exit 8
    fi

}

function createCommit() {
    TIMESTAMP=$(date +%s)
    RESULT=`$CURL_BIN -X POST "https://api.bitbucket.org/2.0/repositories/$BB_REPO_OWNER/$BB_REPO_SLUG/src?ref=$BB_PR_SOURCE" \
     --silent \
     --user $BB_USER:$BB_PASSWORD \
    -H 'application/x-www-form-urlencoded' \
    --data-urlencode "/auto_merge=AUTO $TIMESTAMP" \
    --data-urlencode "message=AutoMerge Commit and Merge" \
    --data-urlencode "branch=$BB_PR_SOURCE" \
    --data-urlencode "author=Automerge Bot <automerge@automerge.com>"
  `
   
        echo $RESULT

}

function sendCommand() {
    RESULT=`$CURL_BIN -X POST "https://api.bitbucket.org/2.0/repositories/$BB_REPO_OWNER/$BB_REPO_SLUG/pullrequests" \
    --silent \
    --user $BB_USER:$BB_PASSWORD \
    -H 'content-type: application/json' \
    -d '{
        "title": "Auto Merge: '$BB_PR_SOURCE' -> '$BB_PR_DESTINATION'",
        "description": "Automatic pull request created.",
        "state": "OPEN",
        "destination": {
        "branch": {
                "name": "'$BB_PR_DESTINATION'"
            }
        },
        "source": {
        "branch": {
                "name": "'$BB_PR_SOURCE'"
            }
        }
    }'`

    # Check for error messages
    ERR_MSG=`echo $RESULT | $JQ_BIN -r '.error.message' || true`

    if [ "$ERR_MSG" == 'null' ]; then
        # No errors, continue
        BB_MERGE_URL=`echo $RESULT | $JQ_BIN -r '.links.merge.href'`

        RESULT=`$CURL_BIN -X POST "$BB_MERGE_URL" \
        --fail --show-error --silent \
        --user $BB_USER:$BB_PASSWORD \
        -H 'content-type: application/json' \
        -d '{
            "close_source_branch": false,
            "merge_strategy": "merge_commit"
        }'`
        echo ""
        echo "Success"
    elif [ "$ERR_MSG" == 'There are no changes to be pulled' ]; then
        # Do we have changes that need to be merged?
        echo "Nothing to do. All changes are already merged."
    else
        echo "BitBucket returned an error: $ERR_MSG"
        echo $RESULT
        exit 9
    fi
}

if [ "$BASH_SOURCE" == "$0" ]; then
    set -o errexit
    set -o pipefail
    set -u
    set -e
    # If no args are provided, display usage information
    if [ $# == 0 ]; then usage; fi

    # Make sure we have out dependancies 
    require curl
    require jq

    # Loop through arguments, two at a time for key and value
    while [[ $# -gt 0 ]]
    do
        key="$1"

        case $key in
            -s|--source)
                BB_PR_SOURCE="$2"
                shift # past argument
                ;;
            -d|--destination)
                BB_PR_DESTINATION="$2"
                shift # past argument
                ;;
            -u|--user)
                BB_USER="$2"
                shift # past argument
                ;;
            -p|--password)
                BB_PASSWORD="$2"
                shift # past argument
                ;;
            --repo-owner)
                BB_REPO_OWNER="$2"
                shift # past argument
                ;;
            --repo-slug)
                BB_REPO_SLUG="$2"
                shift # past argument
                ;;
            --version)
                echo ${VERSION}
                exit 0
                ;;
            *)
                usage
                exit 2
            ;;
        esac
        shift # past argument or value
    done

    # Check that required arguments are provided
    assertRequiredArgumentsSet


    # create and commit new file
    echo "Committing change to branch $BB_PR_SOURCE from user $BB_USER"
    createCommit
    
    # Send command
    echo "Creating and merging pull request from $BB_PR_SOURCE to $BB_PR_DESTINATION"
    sendCommand

    exit 0

fi
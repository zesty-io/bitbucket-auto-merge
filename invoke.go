// Sample helloworld-shell is a Cloud Run shell-script-as-a-service.
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

func main() {

	http.HandleFunc("/", scriptHandler)

	// Determine port for HTTP service.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Yes Defaulting to port %s", port)
	}

	// Start HTTP server.
	log.Printf("Listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}

}

type ScriptBody struct {
	RepoSourceBranch string
	RepoTargetBranch string
	RepoName         string
	RepoUser         string
	BitbucketUser    string
}

func scriptHandler(w http.ResponseWriter, r *http.Request) {

	log.Println("running bit bucket automerge script")

	var sb ScriptBody
	// Try to decode the request body into the struct. If there is an error,
	// respond to the client with the error message and a 400 status code.
	err := json.NewDecoder(r.Body).Decode(&sb)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Println(sb.RepoSourceBranch)
	// get password from authentication header
	reqToken := r.Header.Get("Authorization")
	splitToken := strings.Split(reqToken, "Bearer ")
	reqToken = splitToken[1]

	// output script for debugging
	cmdStr := fmt.Sprintf("script.sh -s %s -d %s -u %s -p %s --repo-owner %s --repo-slug %s", sb.RepoSourceBranch, sb.RepoTargetBranch, sb.BitbucketUser, reqToken, sb.RepoUser, sb.RepoName)
	log.Println(cmdStr)

	// run script
	cmd := exec.CommandContext(r.Context(), "/bin/bash", "script.sh", "-s", sb.RepoSourceBranch, "-d", sb.RepoTargetBranch, "-u", sb.BitbucketUser, "-p", reqToken, "--repo-owner", sb.RepoUser, "--repo-slug", sb.RepoName) //cmdStr)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		w.WriteHeader(500)
	}

	// output results in the return body
	w.Write(out)
}

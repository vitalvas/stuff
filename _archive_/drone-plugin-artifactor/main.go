package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"
)

// BuildCommit is ...
var BuildCommit string

// BuildTime is ...
var BuildTime string
var version string

var envToHTTP = map[string]string{
	"CI":                          "X-CI",
	"CI_SYSTEM":                   "X-CI-System",
	"CI_SYSTEM_LINK":              "X-CI-System-Link",
	"CI_SYSTEM_ARCH":              "X-CI-System-Arch",
	"CI_REPO_LINK":                "X-CI-Repo-Link",
	"CI_REPO_NAME":                "X-CI-Repo-Name",
	"CI_REPO":                     "X-CI-Repo",
	"CI_COMMIT_BRANCH":            "X-CI-Commit-Branch",
	"CI_COMMIT_SHA":               "X-CI-Commit-SHA",
	"CI_COMMIT_REF":               "X-CI-Commit-Ref",
	"CI_COMMIT_AUTHOR_NAME":       "X-CI-Commit-Author-Name",
	"CI_COMMIT_AUTHOR_EMAIL":      "X-CI-Commit-Author-Email",
	"CI_PREV_COMMIT_BRANCH":       "X-CI-Prev-Commit-Branch",
	"CI_PREV_COMMIT_SHA":          "X-CI-Prev-Commit-SHA",
	"CI_PREV_COMMIT_AUTHOR_NAME":  "X-CI-Prev-Commit-Author-Name",
	"CI_PREV_COMMIT_AUTHOR_EMAIL": "X-CI-Prev-Commit-Author-Email",
	"CI_PREV_COMMIT_REF":          "X-CI-Prev-Commit-Ref",
	"CI_BUILD_NUMBER":             "X-CI-Build-Number",
	"CI_BUILD_EVENT":              "X-CI-Build-Event",
	"CI_PREV_BUILD_EVENT":         "X-CI-Prev-Build-Event",
	"CI_PREV_BUILD_STATUS":        "X-CI-Prev-Build-Status",
	"CI_PREV_BUILD_NUMBER":        "X-CI-Prev-Build-Number",
	"CI_NETRC_MACHINE":            "X-CI-Netrc-Machine",
	"CI_REMOTE_URL":               "X-CI-Remote-URL",
}

type postUploadHook struct {
	Type  string
	Vars  map[string]string
	Files []string
}

func init() {
	if len(BuildCommit) > 16 {
		BuildCommit = BuildCommit[:16]
	}
	version = fmt.Sprintf("JotCDN Drone Artifactor (%s; %s)", BuildTime, BuildCommit)
	fmt.Println("Version:", version)
}

func main() {
	files := discoverFiles()
	if len(files) == 0 {
		fmt.Println("No files to upload.")
	} else {
		fmt.Println("Discovered files to upload:")
		for _, n := range files {
			fmt.Println("-", n)
		}
		baseURL := getEnv("PLUGIN_ENDPOINT")

		if !strings.HasPrefix(baseURL, "http://") && !strings.HasPrefix(baseURL, "https://") {
			log.Fatal("Upload endpoint method not supported:", baseURL)
		}

		chroot := getEnv("PLUGIN_CHROOT") == "true"
		stripPrefix := getEnv("PLUGIN_STRIP_PREFIX")
		prefix := getEnv("PLUGIN_PREFIX")
		postUpload := getEnv("PLUGIN_POST_UPLOAD_HOOK")

		poHook := postUploadHook{
			Type: "PostUploadHook",
		}
		if len(postUpload) > 0 {
			vars := make(map[string]string)
			for k, v := range envToHTTP {
				if data := getEnv(k); len(data) > 0 {
					vars[v] = data
				}
			}
			poHook.Vars = vars
		}

		for _, file := range files {
			func() {
				if _, err := os.Stat(file); os.IsNotExist(err) {
					fmt.Println("File not found:", file)
					return
				}
				cURL, err := url.Parse(baseURL)
				if err != nil {
					log.Panic(err)
				}
				if !chroot {
					if cpath := getUploadPrefix(); len(cpath) > 0 {
						if len(prefix) > 0 {
							cURL.Path = path.Join(cURL.Path, prefix)
						} else {
							cURL.Path = path.Join(cURL.Path, "assets")
						}
						cURL.Path = path.Join(cURL.Path, cpath)
					} else {
						fmt.Println("Warning: prepend path not found.")
					}
				}
				vFile := file
				if len(stripPrefix) > 0 {
					vFile = strings.TrimPrefix(vFile, stripPrefix)
				}
				cURL.Path = path.Join(cURL.Path, vFile)
				fmt.Println("Try to upload:", cURL.String())
				dat, err := os.Open(file)
				if err != nil {
					log.Panic(err)
				}
				defer dat.Close()
				upload(cURL.String(), dat)
			}()
		}
		if len(postUpload) > 0 {
			poHook.Files = files
			body, err := json.Marshal(poHook)
			if err != nil {
				log.Panic(err)
			}
			bodyBuf := bytes.NewBuffer(body)
			req, err := http.NewRequest(http.MethodPost, postUpload, bodyBuf)
			if err != nil {
				log.Panic(err)
			}
			req.Header.Add("User-Agent", version)
			client := &http.Client{
				Timeout: time.Second * 15,
			}
			resp, err := client.Do(req)
			if err != nil {
				log.Fatal(err)
			}
			defer resp.Body.Close()
			log.Println("Triggered post upload hook:", postUpload)
		}
	}
}

func discoverFiles() (files []string) {
	pFiles := getEnv("PLUGIN_FILES")
	if len(pFiles) == 0 {
		return
	}
	if strings.Contains(pFiles, ",") {
		for _, vFile := range strings.Split(pFiles, ",") {
			if strings.HasPrefix(vFile, "./") {
				vFile = strings.TrimPrefix(vFile, "./")
			}
			lFiles, err := filepath.Glob(vFile)
			if err != nil {
				log.Fatal(err)
			}
			for _, file := range lFiles {
				files = append(files, file)
			}
		}
	} else {
		if strings.HasPrefix(pFiles, "./") {
			pFiles = strings.TrimPrefix(pFiles, "./")
		}
		lFiles, err := filepath.Glob(pFiles)
		if err != nil {
			log.Fatal(err)
		}
		for _, file := range lFiles {
			files = append(files, file)
		}
	}
	return
}

func upload(baseURL string, body io.Reader) {
	method := strings.ToUpper(getEnv("PLUGIN_METHOD"))
	if method != http.MethodPost && method != http.MethodPut {
		method = http.MethodPut
	}

	req, err := http.NewRequest(method, baseURL, body)
	if err != nil {
		log.Fatal(err)
	}
	req.Header.Add("User-Agent", version)

	for k, v := range envToHTTP {
		if data := getEnv(k); len(data) > 0 {
			req.Header.Add(v, data)
		}
	}

	client := &http.Client{
		Timeout: time.Second * 15,
	}
	resp, err := client.Do(req)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode > 300 {
		fmt.Printf("Response Code: %d, %s", resp.StatusCode, http.StatusText(resp.StatusCode))
		os.Exit(1)
	}
}

func getUploadPrefix() string {
	if data := getEnv("CI_REPO"); len(data) > 0 && strings.Contains(data, "/") {
		return data
	}
	if data := getEnv("DRONE_REPO"); len(data) > 0 && strings.Contains(data, "/") {
		return data
	}
	if data := getEnv("CI_REPO_NAME"); len(data) > 0 && strings.Contains(data, "/") {
		return data
	}
	return ""
}

func getEnv(name string) string {
	return strings.TrimSpace(os.Getenv(name))
}

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

const snapshotPrefix = "Cloud-"

func main() {
	fmt.Println("Initiating instance snapshot at", time.Now().Format(time.RFC3339))
	apiKey, ok := os.LookupEnv("VULTR_API_KEY")
	if !ok || apiKey == "" {
		log.Fatalln("no api key set")
	}

	ms, ok := os.LookupEnv("VULTR_MAX_SNAPSHOTS")
	if !ok {
		ms = "10"
	}

	maxSnapshots, err := strconv.Atoi(ms)
	if err != nil {
		log.Fatalf("failed to get max snapshots for vultr: %v", err)
	}

	fmt.Println("fetching existing snapshots....")
	snapshots, err := fetchSnapshots(apiKey)
	if err != nil {
		log.Fatalf("failed to fetch snapshots: %v", err)
	}

	if len(snapshots)+1 > maxSnapshots {
		toBeDeleted := len(snapshots) + 1 - maxSnapshots
		fmt.Printf("deleting oldest %v snapshots\n", toBeDeleted)
		sort.Sort(snapshots)
		err = deleteSnapshots(apiKey, snapshots[0:toBeDeleted])
		if err != nil {
			log.Fatalf("failed to delete snapshots: %v", err)
		}
	}

	ip, err := fetchPublicIP()
	if err != nil {
		log.Fatalf("failed to fetch instance public ID: %v", err)
	}
	fmt.Println("Instance IP:", ip)

	id, err := fetchInstanceIDByIpv4(ip, apiKey)
	if err != nil {
		log.Fatalf("failed to fetch instance by IP: %v", err)
	}
	fmt.Println("Instance ID:", id)

	snapshot, err := createSnapshot(id, apiKey)
	if err != nil {
		log.Fatalf("failed to create snapshot for instance %v: %v", id, err)
	}
	fmt.Printf("Snapshot(%v) for instance(%v) initiated successfully\n", snapshot, id)
}

func createSnapshot(id, apiKey string) (string, error) {
	t := time.Now().UTC()
	desc := fmt.Sprintf("%s%v", snapshotPrefix, t.Unix())
	payload := map[string]interface{}{
		"instance_id": id,
		"description": desc,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := getVultrRequest(apiKey, "POST", "snapshots", bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}

	defer res.Body.Close()
	return desc, nil
}

type Instances struct {
	Instances []struct {
		ID     string `json:"id"`
		MainIp string `json:"main_ip"`
	} `json:"instances"`
	Meta struct {
		Total int `json:"total"`
		Links struct {
			Next string `json:"next"`
			Prev string `json:"prev"`
		} `json:"links"`
	} `json:"meta"`
}

func fetchInstanceIDByIpv4(ip, apiKey string) (string, error) {
	req, err := getVultrRequest(apiKey, "GET", "instances", nil)
	if err != nil {
		return "", err
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}

	defer res.Body.Close()
	data, err := io.ReadAll(res.Body)
	if err != nil {
		return "", err
	}

	var i Instances
	err = json.Unmarshal(data, &i)
	if err != nil {
		return "", err
	}

	for _, instance := range i.Instances {
		if instance.MainIp == ip {
			return instance.ID, nil
		}
	}

	return "", fmt.Errorf("instance with ip(%v), not found", ip)
}

func getVultrRequest(apiKey, method, path string, body io.Reader) (*http.Request, error) {
	url := fmt.Sprintf("https://api.vultr.com/v2/%s", path)
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))
	return req, nil
}

func fetchPublicIP() (string, error) {
	url := "https://api.ipify.org?format=json"
	res, err := http.Get(url)
	if err != nil {
		return "", err
	}

	defer res.Body.Close()
	var ip struct {
		IP string `json:"ip"`
	}

	data, err := io.ReadAll(res.Body)
	if err != nil {
		return "", err
	}

	return ip.IP, json.Unmarshal(data, &ip)
}

type Snapshot struct {
	ID          string    `json:"id"`
	DateCreated time.Time `json:"date_created"`
	Description string    `json:"description"`
	Size        int64     `json:"size"`
	Status      string    `json:"status"`
	OsID        int       `json:"os_id"`
	AppID       int       `json:"app_id"`
}

type Snapshots []Snapshot

func (snps Snapshots) Len() int {
	return len(snps)
}

func (snps Snapshots) Less(i, j int) bool {
	a, b := snps[i], snps[j]
	return a.DateCreated.Before(b.DateCreated)
}

func (snps Snapshots) Swap(i, j int) {
	snps[i], snps[j] = snps[j], snps[i]
}

type SnapshotResponse struct {
	Snapshots Snapshots `json:"snapshots"`
	Meta      struct {
		Total int `json:"total"`
		Links struct {
			Next string `json:"next"`
			Prev string `json:"prev"`
		} `json:"links"`
	} `json:"meta"`
}

func fetchSnapshots(apiKey string) (Snapshots, error) {
	req, err := getVultrRequest(apiKey, "GET", "snapshots", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request to fetch snapshots: %w", err)
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch snapshots: %w", err)
	}
	defer res.Body.Close()

	data, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var snapRes SnapshotResponse
	err = json.Unmarshal(data, &snapRes)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshall snapshot response: %w", err)
	}

	var snapshots []Snapshot
	for _, snap := range snapRes.Snapshots {
		if !strings.HasPrefix(snap.Description, snapshotPrefix) {
			continue
		}

		snapshots = append(snapshots, snap)
	}

	return snapshots, nil
}

func deleteSnapshots(apiKey string, snapshots []Snapshot) error {
	for _, snapshot := range snapshots {
		req, err := getVultrRequest(apiKey, "DELETE", fmt.Sprintf("snapshots/%s", snapshot.ID), nil)
		if err != nil {
			return err
		}

		res, err := http.DefaultClient.Do(req)
		if err != nil {
			return err
		}

		if res.StatusCode != http.StatusNoContent {
			return fmt.Errorf("failed to delete snapshot: %v", res.StatusCode)
		}

		res.Body.Close()
	}

	return nil
}

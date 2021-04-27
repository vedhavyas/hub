package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "time"
)

func main() {
    fmt.Println("Initiating instance snapshot at", time.Now().Format(time.RFC3339))
    apiKey, ok := os.LookupEnv("VULTR_API_KEY")
    if !ok || apiKey == ""{
        log.Println("no api key set")
        return
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

func createSnapshot(id, apiKey string) (string, error){
    t := time.Now().UTC()
    desc := fmt.Sprintf("Cloud-%v", t.Unix())
    payload := map[string]interface{}{
        "instance_id": id,
        "description": desc,
    }

    data, err := json.Marshal(payload)
    if err != nil {
        return "", err
    }

    url := "https://api.vultr.com/v2/snapshots"
    req, err := http.NewRequest("POST", url, bytes.NewReader(data))
    if err != nil {
        return "", err
    }
    req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))
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
    url := "https://api.vultr.com/v2/instances"
    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return "", err
    }

    req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))
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

    for _, instance := range i.Instances{
        if instance.MainIp == ip{
            return instance.ID, nil
        }
    }

    return "", fmt.Errorf("instance with ip(%v), not found", ip)
}

func fetchPublicIP() (string, error) {
    url := "https://api.ipify.org?format=json"
    res, err := http.Get(url)
    if err != nil {
        return "", err
    }

    defer res.Body.Close()
    var ip struct{
        IP string `json:"ip"`
    }

    data, err := io.ReadAll(res.Body)
    if err != nil {
        return "", err
    }

    return ip.IP, json.Unmarshal(data, &ip)
}

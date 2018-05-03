package main

import (
    "fmt"
    "os"
    "flag"
    "bufio"
    "regexp"
    "github.com/ewgRa/ci-utils/diff_liner"
    "github.com/ewgRa/ci-utils/links_checker"
    "gopkg.in/russross/blackfriday.v2"
    "encoding/json"
    "github.com/google/go-github/github"
)

func main() {
    prLiner := flag.String("pr-liner", "", "Pull request liner")
    fileName := flag.String("file", "", "Hunspell parsed file name")
    expectedCodesFile := flag.String("expected-codes", "", "Expected codes file name")
    flag.Parse()

    if *prLiner == "" || *fileName == "" || *expectedCodesFile == "" {
        flag.Usage()
        os.Exit(1)
    }

    linkRegexp := regexp.MustCompile("href=\"(http[^\"]*)\"")

    linerResp := diff_liner.ReadLinerResponse(*prLiner)
    checker := links_checker.NewChecker(*expectedCodesFile)

    line := 0

    file, err := os.Open(*fileName)

    if err != nil {
        panic(err)
    }

    defer file.Close()

    scanner := bufio.NewScanner(file)

    for scanner.Scan() {
        line++

        prLine := linerResp.GetDiffLine(*fileName, line)

        if prLine == 0 {
            continue
        }

        output := blackfriday.Run(scanner.Bytes())
        matches := linkRegexp.FindAllStringSubmatch(string(output), -1)

        for _, match := range matches {
            link := match[1]

            ok, respCode, expectedCodes := checker.Check(link)

            if ok {
                continue
            }

            body := fmt.Sprintf("Ссылка %s ... недоступна с кодом %v, ожидается %v. Если это ожидаемый ответ, внесите \"%v,%s\" в files/expected_codes.csv", link, respCode, expectedCodes, respCode, link)
            commitID := "FIXME XXX"

            comment := &github.PullRequestComment{
                Body: &body,
                CommitID: &commitID,
                Path: fileName,
                Position: &prLine,
            }

            jsonData, err := json.Marshal(comment)

            if err != nil {
                panic(err)
            }

            fmt.Println(string(jsonData))
        }
    }

    if err := scanner.Err(); err != nil {
        panic(err)

    }
}

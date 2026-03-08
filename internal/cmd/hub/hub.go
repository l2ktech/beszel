package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/henrygd/beszel"
	"github.com/henrygd/beszel/internal/hub"
	_ "github.com/henrygd/beszel/internal/migrations"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/spf13/cobra"
	_ "modernc.org/sqlite"
)

func main() {
	// handle health check first to prevent unneeded execution
	if len(os.Args) > 3 && os.Args[1] == "health" {
		url := os.Args[3]
		if err := checkHealth(url); err != nil {
			log.Fatal(err)
		}
		fmt.Print("ok")
		return
	}

	baseApp := getBaseApp()
	h := hub.NewHub(baseApp)
	if err := h.StartHub(); err != nil {
		log.Fatal(err)
	}
}

// getBaseApp creates a new PocketBase app with the default config
func getBaseApp() *pocketbase.PocketBase {
	isDev := os.Getenv("ENV") == "dev"

	baseApp := pocketbase.NewWithConfig(pocketbase.Config{
		DefaultDataDir: beszel.AppName + "_data",
		DefaultDev:     isDev,
		DBConnect:      connectDBWithPragmas,
	})
	baseApp.RootCmd.Version = beszel.Version
	baseApp.RootCmd.Use = beszel.AppName
	baseApp.RootCmd.Short = ""
	// add update command
	updateCmd := &cobra.Command{
		Use:   "update",
		Short: "Update " + beszel.AppName + " to the latest version",
		Run:   hub.Update,
	}
	updateCmd.Flags().Bool("china-mirrors", false, "Use mirror (gh.beszel.dev) instead of GitHub")
	baseApp.RootCmd.AddCommand(updateCmd)
	// add health command
	baseApp.RootCmd.AddCommand(newHealthCmd())

	// enable auto creation of migration files when making collection changes in the Admin UI
	migratecmd.MustRegister(baseApp, baseApp.RootCmd, migratecmd.Config{
		Automigrate: isDev,
		Dir:         "../../migrations",
	})

	return baseApp
}

func connectDBWithPragmas(dbPath string) (*dbx.DB, error) {
	pragmas := fmt.Sprintf(
		"?_pragma=busy_timeout(10000)&_pragma=journal_mode(%s)&_pragma=journal_size_limit(200000000)&_pragma=synchronous(%s)&_pragma=foreign_keys(ON)&_pragma=temp_store(MEMORY)&_pragma=cache_size(-32000)",
		getSQLiteJournalMode(),
		getSQLiteSynchronousMode(),
	)
	return dbx.Open("sqlite", dbPath+pragmas)
}

func getSQLiteJournalMode() string {
	allowed := map[string]struct{}{
		"DELETE":   {},
		"TRUNCATE": {},
		"PERSIST":  {},
		"MEMORY":   {},
		"WAL":      {},
		"OFF":      {},
	}
	return normalizeSQLitePragma(os.Getenv("BESZEL_HUB_SQLITE_JOURNAL_MODE"), "WAL", allowed)
}

func getSQLiteSynchronousMode() string {
	allowed := map[string]struct{}{
		"OFF":    {},
		"NORMAL": {},
		"FULL":   {},
		"EXTRA":  {},
	}
	return normalizeSQLitePragma(os.Getenv("BESZEL_HUB_SQLITE_SYNCHRONOUS"), "NORMAL", allowed)
}

func normalizeSQLitePragma(value string, fallback string, allowed map[string]struct{}) string {
	normalized := strings.ToUpper(strings.TrimSpace(value))
	if _, ok := allowed[normalized]; ok {
		return normalized
	}
	return fallback
}

func newHealthCmd() *cobra.Command {
	var baseURL string

	healthCmd := &cobra.Command{
		Use:   "health",
		Short: "Check health of running hub",
		Run: func(cmd *cobra.Command, args []string) {
			if err := checkHealth(baseURL); err != nil {
				log.Fatal(err)
			}
			os.Exit(0)
		},
	}
	healthCmd.Flags().StringVar(&baseURL, "url", "", "base URL")
	healthCmd.MarkFlagRequired("url")
	return healthCmd
}

// checkHealth checks the health of the hub.
func checkHealth(baseURL string) error {
	client := &http.Client{
		Timeout: time.Second * 3,
	}
	healthURL := baseURL + "/api/health"
	resp, err := client.Get(healthURL)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("%s returned status %d", healthURL, resp.StatusCode)
	}
	return nil
}

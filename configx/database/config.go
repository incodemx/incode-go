package database

import (
	"flag"
	"fmt"

	"github.com/incodemx/incode-go/configx/helper"
)

// NewConfiguration defines and loads the configuration from flags and environment variables.
func NewConfiguration() (*Configuration, error) {
	cfg := &Configuration{}

	dbURL := helper.Load("DB_URL", "")
	flag.StringVar(&cfg.URL, "db.url", dbURL, "Database connection URL (e.g., file:data.sqlite3)")

	dbDriver := helper.Load("DB_DRIVER", "sqlite3")
	flag.StringVar(&cfg.Driver, "db.driver", dbDriver, "Database driver (e.g., sqlite3)")

	dbExtensions := helper.Load("DB_EXTENSIONS", "")
	flag.StringVar(&cfg.Extensions, "db.extensions", dbExtensions, "SQLite-only: Load the UUID extension (e.g., /usr/lib/sqlite3/uuid.so)")

	return cfg, nil
}

// Build should be called *after* flag.Parse() to perform final setup.
func (c *Configuration) Build() error {
	if c == nil {
		return fmt.Errorf("database configuration is nil")
	}

	if c.URL == "" {
		return fmt.Errorf("database URL is required: set DB_URL environment variable or use the -db.url flag")
	}

	if c.Driver == "" {
		return fmt.Errorf("database driver is required: set DB_DRIVER environment variable or use the -db.driver flag")
	}

	return nil
}

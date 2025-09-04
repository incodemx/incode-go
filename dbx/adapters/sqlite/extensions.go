package sqlite

import (
	"database/sql"
	"fmt"
	"strings"
	"sync"

	"github.com/mattn/go-sqlite3"
)

// Register registers a new driver name that enables
// load_extension and loads the given shared libraries on every new connection.
// It is safe to call multiple times with the same name; registration will only happen once.
func register(driverName string, extensionPaths []string) error {

	if len(extensionPaths) == 0 {
		return nil
	}

	var once sync.Once
	var regErr error

	once.Do(func() {
		sql.Register(driverName, &sqlite3.SQLiteDriver{
			ConnectHook: func(conn *sqlite3.SQLiteConn) error {
				// load each extension (empty entry point = default sqlite3_extension_init)
				for _, p := range extensionPaths {
					if err := conn.LoadExtension(p, ""); err != nil {
						return fmt.Errorf("LoadExtension(%s): %w", p, err)
					}
				}
				return nil
			},
		})
	})

	return regErr
}

func splitExtensions(extensionList string) []string {
	if extensionList != "" {
		extensions := strings.Split(extensionList, ",")
		for i := range extensions {
			extensions[i] = strings.TrimSpace(extensions[i])
		}
		return extensions
	}
	return []string{}
}

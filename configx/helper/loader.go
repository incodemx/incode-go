package helper

import "os"

// Load is a helper to read an environment variable or return a default value.
func Load(envVar string, defaultVal string) string {
	if value, exists := os.LookupEnv(envVar); exists {
		return value
	}
	return defaultVal
}

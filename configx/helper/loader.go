package helper

import (
	"os"
	"strconv"
)

// Load is a helper to read an environment variable or return a default value.
func Load(envVar string, defaultVal string) string {
	if value, exists := os.LookupEnv(envVar); exists {
		return value
	}
	return defaultVal
}

// Load is a helper to read an environment variable or return a default value.
func LoadInt(envVar string, defaultVal int) int {
	if value, exists := os.LookupEnv(envVar); exists {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultVal
}

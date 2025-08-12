package configx

// Configuration holds the server-specific configuration.
type Configuration struct {
	Address   string
	URL       string
	Port      string
	Env       string
	Cert      string
	Key       string
	Assets    string
	JWTSecret string
}

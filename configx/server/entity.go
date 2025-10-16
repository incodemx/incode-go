package server

// Configuration holds the server-specific configuration.
type Configuration struct {
	Address string
	URL     string
	Port    string
	Env     string
	Cert    string
	Key     string
	Assets  string
	JWT     JWTConfiguration
}

type JWTConfiguration struct {
	Secret   string
	Issuer   string
	Audience string
	Duration int
}

package configx

import (
	"github.com/incodemx/incode-go/configx/helper"

	"flag"
	"fmt"
)

// NewApplicationConfiguration defines and loads the configuration from flags and environment variables.
func NewApplicationConfiguration() (*Configuration, error) {
	cfn := &Configuration{}

	env := helper.Load("ENV", "production")
	flag.StringVar(&cfn.Env, "server.env", env, "Environment (development, production)")

	url := helper.Load("URL", "0.0.0.0")
	flag.StringVar(&cfn.URL, "server.url", url, "Server host URL")

	port := helper.Load("PORT", "8080")
	flag.StringVar(&cfn.Port, "server.port", port, "Port to run the server on")

	cert := helper.Load("CERT", "")
	flag.StringVar(&cfn.Cert, "server.cert", cert, "SSL certificate file")

	key := helper.Load("KEY", "")
	flag.StringVar(&cfn.Key, "server.key", key, "SSL key file")

	assets := helper.Load("ASSETS_DIRECTORY", "./build/static")
	flag.StringVar(&cfn.Assets, "server.assets", assets, "Path to static assets directory")

	jwtSecret := helper.Load("JWT_SECRET", "default-secret")
	flag.StringVar(&cfn.JWTSecret, "server.jwt-secret", jwtSecret, "Secret key for signing JWTs")

	return cfn, nil
}

// Build should be called *after* flag.Parse() to perform final setup.
func (c *Configuration) Build() error {
	c.Address = fmt.Sprintf("%s:%s", c.URL, c.Port)
	return nil
}

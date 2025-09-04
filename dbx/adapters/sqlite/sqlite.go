package sqlite

import (
	"database/sql"
	"errors"
	"fmt"
	"log"

	"github.com/jmoiron/sqlx"
	_ "github.com/mattn/go-sqlite3"

	"github.com/incodemx/incode-go/configx/database"
	"github.com/incodemx/incode-go/dbx"
)

const (
	errMsgNotConnected = "datastore is not connected"
)

// connection implements the Connection interface.
type connection struct {
	db *sqlx.DB
}

// NewConnection creates a new database connection.
func NewConnection(config *database.Configuration) (dbx.Connection, error) {
	databaseUrl := config.URL
	if databaseUrl == "" {
		return nil, fmt.Errorf("datastore url is not set in the configuration")
	}

	driver := config.Driver
	if driver == "" {
		return nil, fmt.Errorf("datastore driver is not set in the configuration")
	}

	if config.Extensions != "" {
		driver = "sqlite3_extended"
		extensions := splitExtensions(config.Extensions)
		if err := register(driver, extensions); err != nil {
			return nil, fmt.Errorf("register sqlite extensions driver: %w", err)
		}
	}

	dbc, err := sqlx.Connect(driver, databaseUrl)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to datastore: %v", err)
	}

	if err := dbc.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database after connecting: %w", err)
	}

	log.Println("Datastore is connected!")

	return &connection{db: dbc}, nil
}

// Ping checks if the database connection is alive.
func (c *connection) Ping() error {
	return c.db.Ping()
}

// Close closes the database connection.
func (c *connection) Close() error {
	return c.db.Close()
}

// Execute executes a query that doesn't return rows, such as an INSERT or UPDATE.
func (c *connection) Execute(query string, args any) (sql.Result, error) {
	if c == nil || c.db == nil {
		return nil, errors.New(errMsgNotConnected)
	}
	return c.db.NamedExec(query, args)
}

// Query executes a query that returns rows, such as a SELECT statement.
func (c *connection) Query(query string, args any) (*sqlx.Rows, error) {
	if c == nil || c.db == nil {
		return nil, errors.New(errMsgNotConnected)
	}
	return c.db.NamedQuery(query, args)
}

// Get retrieves a single row from the database and maps it to the provided destination struct.
func (c *connection) Get(dest any, query string, args any) error {
	if c == nil || c.db == nil {
		return errors.New(errMsgNotConnected)
	}

	query = c.db.Rebind(query)
	stmt, err := c.db.PrepareNamed(query)
	if err != nil {
		return fmt.Errorf("failed to prepare named statement: %w", err)
	}
	defer stmt.Close()

	err = stmt.Get(dest, args)
	if err != nil {
		return fmt.Errorf("failed to execute get statement: %w", err)
	}

	return nil
}

// BeginTx starts a new database transaction.
func (c *connection) BeginTx() (dbx.Transaction, error) {
	tx, err := c.db.Beginx()
	if err != nil {
		return nil, err
	}
	return &transaction{tx: tx}, nil
}

// --- Transaction Implementation ---

// transaction implements the Transaction interface.
type transaction struct {
	tx *sqlx.Tx
}

// Execute executes a query within the transaction.
func (t *transaction) Execute(query string, args any) (sql.Result, error) {
	return t.tx.NamedExec(query, args)
}

// Query executes a query within the transaction.
func (t *transaction) Query(query string, args any) (*sqlx.Rows, error) {
	return t.tx.NamedQuery(query, args)
}

// Get executes a query and scans the result within the transaction.
func (t *transaction) Get(dest any, query string, args any) error {
	query = t.tx.Rebind(query)
	stmt, err := t.tx.PrepareNamed(query)
	if err != nil {
		return err
	}
	defer stmt.Close()
	return stmt.Get(dest, args)
}

// Commit commits the transaction.
func (t *transaction) Commit() error {
	return t.tx.Commit()
}

// Rollback rolls back the transaction.
func (t *transaction) Rollback() error {
	return t.tx.Rollback()
}

// Select executes a query that returns multiple rows and scans them into the 'dest' slice.
func (c *connection) Select(dest any, query string, args any) error {
	if c == nil || c.db == nil {
		return errors.New(errMsgNotConnected)
	}
	// If args is a map, use sqlx.Named to bind the parameters
	// Otherwise, treat args as a slice of arguments.
	// This allows for both positional and named parameters.
	query = c.db.Rebind(query)
	if argsMap, ok := args.(map[string]any); ok {
		query, boundArgs, err := sqlx.Named(query, argsMap)
		if err != nil {
			return err
		}
		query = sqlx.Rebind(sqlx.BindType(c.db.DriverName()), query)
		return c.db.Select(dest, query, boundArgs...)
	}
	return c.db.Select(dest, query)
}

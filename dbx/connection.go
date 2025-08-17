package dbx

import (
	"database/sql"

	"github.com/jmoiron/sqlx"
)

// Connection defines the interface for our database operations.
type Connection interface {
	BeginTx() (Transaction, error)
	Ping() error
	Close() error
	Execute(query string, args any) (sql.Result, error)
	Query(query string, args any) (*sqlx.Rows, error)
	Get(dest any, query string, args any) error
	Select(dest any, query string, args any) error
}

// Transaction defines the interface for methods that can be run within a DB transaction.
// It mirrors the DatabaseConnection interface but operates on a sqlx.Tx object.
type Transaction interface {
	Execute(query string, args any) (sql.Result, error)
	Query(query string, args any) (*sqlx.Rows, error)
	Get(dest any, query string, args any) error
	Commit() error
	Rollback() error
}

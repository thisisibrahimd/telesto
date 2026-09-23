package repository

type ForUserRepo[T any] interface {
	ForUser(id string) *T
}

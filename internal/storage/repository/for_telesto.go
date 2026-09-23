package repository

type ForTelestoRepo[T any] interface {
	ForTelesto(id string) *T
}

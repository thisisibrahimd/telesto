package fxutils

import (
	"fmt"

	"go.uber.org/fx"
)

func ConditionalOptions(condition func() bool, options ...fx.Option) []fx.Option {
	if condition() {
		return options
	} else {
		return nil
	}
}

func ConditionalOption(condition func() bool, option fx.Option) fx.Option {
	if condition() {
		return option
	} else {
		return nil
	}
}

func ProvideGroupOptions[T any](groupName string, options ...T) fx.Option {
	return fx.Provide(
		fx.Annotate(
			func() []T { return options },
			fx.ResultTags(fmt.Sprintf(`group:"%s,flatten"`, groupName)),
		),
	)
}

func ProvideGroupOption[T any](groupName string, option T) fx.Option {
	return fx.Provide(
		fx.Annotate(
			option,
			fx.ResultTags(fmt.Sprintf(`group:"%s"`, groupName)),
		),
	)
}

func ProvideSuppliedGroupOption[T any](groupName string, option T) fx.Option {
	return fx.Provide(
		fx.Annotate(
			WrapO(option),
			fx.ResultTags(fmt.Sprintf(`group:"%s"`, groupName)),
		),
	)
}

func ConsumeAndProvideSuppliedGroupOption[T any](consumingGroupName string, providingGroupName string, option T) fx.Option {
	return fx.Provide(
		fx.Annotate(
			WrapO(option),
			fx.ParamTags(fmt.Sprintf(`group:"%s"`, consumingGroupName)),
			fx.ResultTags(fmt.Sprintf(`group:"%s"`, providingGroupName)),
		),
	)
}
func ConsumeAndProvideGroupOption[T any](consumingGroupName string, providingGroupName string, option T) fx.Option {
	return fx.Provide(
		fx.Annotate(
			option,
			fx.ParamTags(fmt.Sprintf(`group:"%s"`, consumingGroupName)),
			fx.ResultTags(fmt.Sprintf(`group:"%s"`, providingGroupName)),
		),
	)
}
func ConsumeGroupOptions[T any](groupName string, consumer T) fx.Option {
	return fx.Provide(
		fx.Annotate(
			consumer,
			fx.ParamTags(fmt.Sprintf(`group:"%s"`, groupName)),
		),
	)
}

func WrapO[T any](o T) func() T {
	return func() T { return o }
}

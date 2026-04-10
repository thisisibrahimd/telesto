//go:build tools

package main

import (
	"flag"
	"fmt"
	"log"
	"log/slog"
	"os"
	"slices"
	"strings"
	"text/template"

	"github.com/Masterminds/sprig/v3"
	mapset "github.com/deckarep/golang-set/v2"
	"github.com/iancoleman/strcase"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

func getSafeResourceName(location string) string {
	// Remove trailing slashes so the last element isn't empty
	cleanLoc := strings.Trim(location, "/")
	parts := strings.Split(cleanLoc, "/")

	if len(parts) == 0 {
		return "Unknown"
	}

	return parts[len(parts)-1]
}

func getType(s *jsonschema.Schema) string {
	if s.Types == nil {
		return ""
	}
	if len(s.Types.ToStrings()) != 1 {
		panic("multiple types not supported")
	}
	return s.Types.ToStrings()[0]
}

func getActualJsonSchema(s *jsonschema.Schema) *jsonschema.Schema {
	if s.Ref != nil {
		return s.Ref
	}
	return s
}

func getSpecNodeJsonKey(s *SpecNode, prevKeys []string) []string {
	if s.PrevSpecNode == nil || s.PrevSpecNode.DONTGENBEFOREME == true || s.PrevSpecNode.GenerateArray == true {
		return prevKeys
	}

	prevKeys = append(prevKeys, s.PrevSpecNode.Name)

	keys := getSpecNodeJsonKey(s.PrevSpecNode, prevKeys)

	return keys

}
func printSpec(s *SpecNode, depth int) {
	if s == nil {
		return
	}

	fmt.Printf("%s%s (jsonKey:%s) (%t):\n", strings.Repeat("  ", depth), s.Name, strings.Join(s.JsonPath, "."), s.Generate)
	schemas := slices.Concat(s.Properties)
	for _, subS := range schemas {
		printSpec(subS, depth+1)
	}

}

type SpecNode struct {
	Name                string
	FunctionName        string
	PrevSpecNode        *SpecNode
	DONTGENBEFOREME     bool
	JsonPath            []string
	CustomJsonKey       string
	CustomJsonValueName string
	Generate            bool
	GenerateArray       bool
	GenerateNamed       bool
	GenerateSubProps    bool
	Properties          []*SpecNode
}

func (n *SpecNode) genJsonPath() {
	jsonKey := getSpecNodeJsonKey(n, []string{})
	slices.Reverse(jsonKey)

	// remove library name
	n.JsonPath = slices.DeleteFunc(jsonKey, func(s string) bool { return s == "openapi" })
}

var ComponentNames mapset.Set[string] = mapset.NewSet[string]()

func generateSpec(s *jsonschema.Schema) *SpecNode {
	s = getActualJsonSchema(s)
	schemaName := getSafeResourceName(s.Location)
	schemaType := getType(s)
	spec := &SpecNode{Name: strcase.ToLowerCamel(schemaName)}
	slog.Info("generating spec", "schema", schemaName, "num-of-props", len(s.Properties))
	if schemaType == "array" {
		spec.Generate = true
		spec.GenerateArray = true
		spec.DONTGENBEFOREME = true
		return spec
	}

	if schemaName == "Reference" {
		spec.FunctionName = "Ref"
		spec.CustomJsonKey = "\"$ref\""
		spec.CustomJsonValueName = "ref"
	}

	if schemaName == "Schema" || schemaName == "MediaType" || schemaName == "Example" || schemaName == "Encoding" || schemaName == "Header" {
		spec.Generate = true
		return spec
	}

	if len(s.Properties) == 0 {
		spec.Generate = true
	}

	for propertyName, property := range s.Properties {
		property = getActualJsonSchema(property)
		propertyType := getType(property)
		slog.Info("parsing property", "name", propertyName, "type", propertyType)

		propertySpecNode := generateSpec(property)
		switch propertyName {
		case "$ref":
			propertySpecNode.CustomJsonKey = "\"$ref\""
			propertySpecNode.FunctionName = "Ref"
		case "in":
			propertySpecNode.CustomJsonKey = "\"in\""
			propertySpecNode.CustomJsonValueName = "in_"
		default:
			propertySpecNode.Name = propertyName
		}

		propertySpecNode.PrevSpecNode = spec
		spec.Properties = append(spec.Properties, propertySpecNode)
		slog.Info("found an endpoint", "name", propertyName, "loc", property.Location)
	}

	for _, patternProperty := range s.PatternProperties {
		if patternProperty.Ref == nil && len(patternProperty.OneOf) == 0 {
			continue
		}
		if len(patternProperty.OneOf) != 0 {
			for _, oneOfProperty := range patternProperty.OneOf {
				spec.GenerateSubProps = true
				oneOfProperty = getActualJsonSchema(oneOfProperty)
				oneOfPropertyName := getSafeResourceName(oneOfProperty.Location)
				oneOfPropertyType := getType(oneOfProperty)
				slog.Info("parsing property", "name", oneOfPropertyName, "type", oneOfPropertyType)

				oneOfPropertySpecNode := generateSpec(oneOfProperty)
				oneOfPropertySpecNode.PrevSpecNode = spec
				oneOfPropertySpecNode.Generate = false
				oneOfPropertySpecNode.DONTGENBEFOREME = true
				if len(oneOfPropertySpecNode.Properties) != 0 {
					oneOfPropertySpecNode.GenerateSubProps = true
				}
				spec.Properties = append(spec.Properties, oneOfPropertySpecNode)
			}
			continue
		}
		slog.Info("let", "ONEOFPROP🤖S", len(patternProperty.OneOf))
		spec.GenerateSubProps = true
		patternProperty = getActualJsonSchema(patternProperty)
		patternPropertyName := getSafeResourceName(patternProperty.Location)
		patternPropertyType := getType(patternProperty)
		slog.Info("parsing property", "name", patternPropertyName, "type", patternPropertyType)

		patternPropertySpecNode := generateSpec(patternProperty)
		patternPropertySpecNode.PrevSpecNode = spec
		patternPropertySpecNode.Generate = false
		patternPropertySpecNode.DONTGENBEFOREME = true
		patternPropertySpecNode.GenerateSubProps = false
		spec.Properties = append(spec.Properties, patternPropertySpecNode)
		slog.Info("found an endpoint", "name", patternPropertyName, "loc", patternProperty.Location)
	}

	// if len(s.Properties) == 0 && len(s.OneOf) != 0 {
	// 	for _, oneOfProperty := range s.OneOf {
	// 		oneOfProperty = getActualJsonSchema(oneOfProperty)
	// 		oneOfPropertyName := getSafeResourceName(oneOfProperty.Location)
	// 		oneOfPropertyType := getType(oneOfProperty)
	// 		slog.Info("parsing property", "name", oneOfPropertyName, "type", oneOfPropertyType)

	// 		oneOfPropertySpecNode := generateSpec(oneOfProperty)
	// 		oneOfPropertySpecNode.PrevSpecNode = spec
	// 		oneOfPropertySpecNode.Generate = false
	// 		oneOfPropertySpecNode.GenerateSubProps = false
	// 		spec.Properties = append(spec.Properties, oneOfPropertySpecNode)
	// 	}
	// }

	return spec
}

func genJsonPathsForSpecs(s *SpecNode) {
	for _, property := range s.Properties {
		property.genJsonPath()
		genJsonPathsForSpecs(property)
	}
}

func main() {
	jsonSchemaFile := flag.String("json-schema", "", "path to json schema file")
	libraryName := flag.String("library-name", "", "name of library")
	tmplFile := flag.String("template-file", "", "name of library")
	parseFlag := flag.Bool("parse", false, "")
	outFile := flag.String("output", "", "")
	flag.Parse()

	if jsonSchemaFile == nil || *jsonSchemaFile == "" {
		log.Fatal("json-schema flag not provided")
	}
	if libraryName == nil || *libraryName == "" {
		log.Fatal("library-name flag not provided")
	}

	c := jsonschema.NewCompiler()
	rootJsonSchema, err := c.Compile(*jsonSchemaFile)
	if err != nil {
		log.Fatal(err)
	}

	rootSpec := generateSpec(rootJsonSchema)
	rootSpec.Name = "openapi"
	genJsonPathsForSpecs(rootSpec)

	if *parseFlag {
		printSpec(rootSpec, 0)
	} else {
		output, err := os.Create(*outFile)
		defer output.Close()
		if err != nil {
			panic(err)
		}

		tmpl, err := template.New("jsonnet.tmpl").Funcs(sprig.FuncMap()).ParseFiles(*tmplFile)
		err = tmpl.Execute(output, rootSpec)
		if err != nil {
			panic(err)
		}
	}

}

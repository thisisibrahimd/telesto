package main

import (
	"fmt"
	"os"

	"github.com/adrg/xdg"
	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humagin"
	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/config"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/db/query"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/models"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/server/routes"
	"gorm.io/gorm"
)

var telestoCfg *config.Config
var gormDb *gorm.DB
var router *gin.Engine

var telestoCmd = &cobra.Command{
	Use: "telesto",
	Run: func(cmd *cobra.Command, args []string) {
		router.Run(fmt.Sprintf("%s:%d", telestoCfg.Host, telestoCfg.Port)) // listens on 0.0.0.0:8080 by default
	},
}

func main() {
	// setup config
	telestoCfg = &config.Config{}

	// setup viper
	viperCfg := viper.New()
	viperCfg.SetConfigName("telesto")

	// Add search paths to find the file
	viperCfg.AddConfigPath("/etc/telesto/")
	viperCfg.AddConfigPath(xdg.ConfigHome)
	viperCfg.AddConfigPath(".")

	// setup env config support
	viperCfg.SetEnvPrefix("TL")
	viperCfg.AutomaticEnv()

	// bind config values to cmd flags
	telestoCfg.SetFlags(telestoCmd, viperCfg)

	// define and read command line flags
	telestoCmd.PersistentFlags().StringP("config", "c", "", "config file")
	if err := telestoCmd.ParseFlags(os.Args); err != nil {
		log.Err(err).Msg("unable to read flags")
		return
	}
	configFile, err := telestoCmd.PersistentFlags().GetString("config")
	if err != nil {
		log.Err(err).Msg("unable to read config flag")
		return
	}

	// read config
	if configFile != "" {
		viperCfg.SetConfigFile(configFile)
	}
	if err := viperCfg.ReadInConfig(); err != nil {
		log.Fatal().AnErr("err", err).Str("file", viper.ConfigFileUsed()).Msg("unable to read config")
	}
	log.Info().Str("file", viperCfg.ConfigFileUsed()).Msg("loaded config file")
	if err := viperCfg.Unmarshal(telestoCfg); err == nil {
		log.Info().Msg("loaded config into memory")
	}

	// setup db
	gormDb, err = gorm.Open(sqlite.Open(telestoCfg.Database.SQLite.File), &gorm.Config{})
	if err != nil {
		log.Err(err).Msg("unable to open sqlite db")
	}

	// migrate db
	if err := gormDb.AutoMigrate(&models.OtelCol{}); err != nil {
		log.Err(err).Msg("database migration failed")
	}

	// setup gorm dao for db
	suppliedQuery := query.Use(gormDb)

	// setup http server and routes
	router = gin.Default()
	// router.Use(handlers.ErrorHandler())

	apiConfig := huma.DefaultConfig("Telesto API", "1.0.0")
	apiConfig.FieldsOptionalByDefault = true
	api := humagin.New(router, apiConfig)
	apiRoutes := routes.NewServerRoutes().WithAPI(api).WithQuery(suppliedQuery)
	apiRoutes.SetupRoutes()

	// launch command
	if err := telestoCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/mdobak/go-xerrors"
	"github.com/spf13/cobra"
)

type LoginOptions struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Raw      bool
}

func NewLoginCommand() *cobra.Command {
	opts := &LoginOptions{}

	cmd := &cobra.Command{
		Use: "login",
		PreRunE: func(cmd *cobra.Command, args []string) error {
			// validate initial user creds

			username := os.Getenv("TELESTO_USERNAME")
			password := os.Getenv("TELESTO_PASSWORD")

			var err error
			if username == "" {
				xerrors.Append(err, xerrors.New("TELESTO_USERNAME is missing"))
			}
			if password == "" {
				xerrors.Append(err, xerrors.New("TELESTO_PASSWORD is missing"))
			}

			if err != nil {
				return err
			}
			opts.Username = username
			opts.Password = password

			return nil
		},
		Run: func(cmd *cobra.Command, args []string) {

			// create client
			endpoint, _ := cmd.Flags().GetString("endpoint")

			// login
			loginData := map[string]any{
				"username": opts.Username,
				"password": opts.Password,
			}
			loginDataBody, _ := json.Marshal(loginData)
			resp, err := http.Post(fmt.Sprintf("%s/auth/login", endpoint), "application/json", bytes.NewReader(loginDataBody))
			if err != nil {
				fmt.Println(err.Error())
			}

			cookies := resp.Cookies()
			authCookie := cookies[0]

			// get token
			req, _ := http.NewRequest(http.MethodPost, fmt.Sprintf("%s/auth/token", endpoint), nil)
			req.AddCookie(authCookie)

			resp, _ = http.DefaultClient.Do(req)

			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			type tokenRes struct {
				Token string `json:"token"`
			}
			parsedBody := &tokenRes{}
			json.Unmarshal(body, parsedBody)

			if opts.Raw {
				fmt.Println(parsedBody.Token)
			} else {
				fmt.Printf("safely your token: %s\n", parsedBody.Token)
				fmt.Printf("or export: export TELESTO_TOKEN=%s\n", parsedBody.Token)
			}
		},
	}

	cmd.Flags().BoolVarP(&opts.Raw, "raw", "r", false, "output the token raw")

	return cmd
}

package server

import (
	"github.com/danielgtaylor/huma/v2/humatest"
	"github.com/stretchr/testify/suite"
	"github.com/thisisibrahimd/telesto/internal/storage"
)

type ServerTestSuite struct {
	suite.Suite
	storage *storage.Storage
	srv     *Server
	testApi humatest.TestAPI
}

// func (suite *ServerTestSuite) SetupTest() {
// 	// run rqlite db
// 	err := exec.Command("just", "start-db").Start()
// 	require.NoError(suite.T(), err)
// 	err = exec.Command("just", "wait-for-db").Run()
// 	require.NoError(suite.T(), err)
// 	err = exec.Command("just", "init-db").Run()
// 	require.NoError(suite.T(), err)

// 	l := telemetry.NewLogger()
// 	// create storage obj
// 	sto, _ := storage.NewStorage(storage.WithDSN("http://127.0.0.1:4001"), storage.WithLogger(l))
// 	suite.storage = sto

// 	a := auth.NewAuth(auth.NewAuthConfig(sto, l))

// 	_, api := humatest.New(suite.T())
// 	handlers.RegisterHandlers(api, sto, middlewares.NewAuthenticatedMiddleware(middlewares.WithAuth(a)))
// 	suite.testApi = api

// 	srv := NewServer(WithLogger(l), WithStorage(sto), WithAuth(a), WithAddress("127.0.0.1:9000"))
// 	suite.srv = srv
// }

// func (suite *ServerTestSuite) TearDownTest() {
// 	suite.T().Log("tearing down test")
// 	err := exec.Command("just", "stop-db").Run()
// 	require.NoError(suite.T(), err)
// }

// func (suite *ServerTestSuite) TestListOtelcols() {
// 	resp := suite.testApi.Get("/api/v1/otelcol/")
// 	suite.Assert().Equal(http.StatusOK, resp.Code)
// }

// func (suite *ServerTestSuite) TestAuthLogin() {
// 	// prepare request
// 	asdf := map[string]any{"username": "ibrahim", "password": "Password1!"}
// 	body, _ := json.Marshal(asdf)
// 	req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
// 	w := httptest.NewRecorder()

// 	// send request
// 	suite.srv.router.ServeHTTP(w, req)

// 	// assert result
// 	res := w.Result()
// 	cookies := res.Cookies()
// 	authCookie := cookies[0]
// 	suite.Assert().Equal(http.StatusFound, res.StatusCode)
// 	suite.Assert().Len(cookies, 1)
// 	suite.Assert().Equal(authCookie.Name, "telesto_auth")
// }

// func (suite *ServerTestSuite) TestAuthToken() {
// 	asdf := map[string]any{"username": "ibrahim", "password": "Password1!"}
// 	body, _ := json.Marshal(asdf)
// 	req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
// 	w := httptest.NewRecorder()

// 	suite.srv.router.ServeHTTP(w, req)

// 	res := w.Result()
// 	cookies := res.Cookies()
// 	authCookie := cookies[0]
// 	suite.Assert().Equal(http.StatusFound, res.StatusCode)
// 	suite.Assert().Len(cookies, 1)
// 	suite.Assert().Equal(authCookie.Name, "telesto_auth")

// 	// get token
// 	req = httptest.NewRequest(http.MethodPost, "/auth/token", nil)
// 	req.AddCookie(authCookie)
// 	w = httptest.NewRecorder()

// 	suite.srv.router.ServeHTTP(w, req)

// 	res = w.Result()
// 	defer res.Body.Close()
// 	body, _ = io.ReadAll(res.Body)
// 	type tokenRes struct {
// 		Token string `json:"token"`
// 	}
// 	parsedBody := &tokenRes{}
// 	json.Unmarshal(body, parsedBody)
// 	suite.Assert().Equal(http.StatusOK, res.StatusCode)
// 	suite.Assert().NotEmpty(parsedBody.Token)
// }

// func (suite *ServerTestSuite) sendRequest(method string, path string, body map[string]any) {

// }

// func TestServerTestSuite(t *testing.T) {
// 	suite.Run(t, new(ServerTestSuite))
// }

{
  server: {
    private: {
      externalSecrets: {
        withToken(token): {
          server+: {
            private+: {
              externalSecrets+: {
                token: token,
              },
            },
          },
        },
      },
      telestoDeployer: {
        withToken(token): {
          server+: {
            private+: {
              telestoDeployer+: {
                token: token,
              },
            },
          },
        },
      },
      tls: {
        withCaCert(caCert): {
          server+: {
            private+: {
              tls+: {
                caCert: caCert,
              },
            },
          },
        },
        withCert(cert): {
          server+: {
            private+: {
              tls+: {
                cert: cert,
              },
            },
          },
        },
        withKey(key): {
          server+: {
            private+: {
              tls+: {
                key: key,
              },
            },
          },
        },
      },
      withAddress(address): {
        server+: {
          private+: {
            address: address,
          },
        },
      },
    },
    public: {
      auth: {
        kratos: {
          withInternalEndpoint(internalEndpoint): {
            server+: {
              public+: {
                auth+: {
                  kratos+: {
                    internalEndpoint: internalEndpoint,
                  },
                },
              },
            },
          },
          withPublicEndpoint(publicEndpoint): {
            server+: {
              public+: {
                auth+: {
                  kratos+: {
                    publicEndpoint: publicEndpoint,
                  },
                },
              },
            },
          },
        },
      },
      cookies: {
        withCookieEncKey(cookieEncKey): {
          server+: {
            public+: {
              cookies+: {
                cookieEncKey: cookieEncKey,
              },
            },
          },
        },
        withCookieStoreKey(cookieStoreKey): {
          server+: {
            public+: {
              cookies+: {
                cookieStoreKey: cookieStoreKey,
              },
            },
          },
        },
        withSessionEncKey(sessionEncKey): {
          server+: {
            public+: {
              cookies+: {
                sessionEncKey: sessionEncKey,
              },
            },
          },
        },
        withSessionStoreKey(sessionStoreKey): {
          server+: {
            public+: {
              cookies+: {
                sessionStoreKey: sessionStoreKey,
              },
            },
          },
        },
      },
      csrf: {
        withKey(key): {
          server+: {
            public+: {
              csrf+: {
                key: key,
              },
            },
          },
        },
      },
      tls: {
        withCaCert(caCert): {
          server+: {
            public+: {
              tls+: {
                caCert: caCert,
              },
            },
          },
        },
        withCert(cert): {
          server+: {
            public+: {
              tls+: {
                cert: cert,
              },
            },
          },
        },
        withKey(key): {
          server+: {
            public+: {
              tls+: {
                key: key,
              },
            },
          },
        },
      },
      withAddress(address): {
        server+: {
          public+: {
            address: address,
          },
        },
      },
      withBaseUrl(baseUrl): {
        server+: {
          public+: {
            baseUrl: baseUrl,
          },
        },
      },
    },
  },
  storage: {
    withDsn(dsn): {
      storage+: {
        dsn: dsn,
      },
    },
    withMigrate(migrate): {
      storage+: {
        migrate: migrate,
      },
    },
  },
  telemetry: {
    log: {
      withDebug(debug): {
        telemetry+: {
          log+: {
            debug: debug,
          },
        },
      },
      withFormat(format): {
        telemetry+: {
          log+: {
            format: format,
          },
        },
      },
    },
  },
}

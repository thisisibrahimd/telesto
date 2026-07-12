{
  openapi: {
    info: {
      license: {
        withName(name): { info+: { license+: { name: name } } },

        withUrl(url): { info+: { license+: { url: url } } },

      },
      withVersion(version): { info+: { version: version } },

      withTitle(title): { info+: { title: title } },

      withDescription(description): { info+: { description: description } },

      withTermsOfService(termsOfService): { info+: { termsOfService: termsOfService } },


      contact: {
        withName(name): { info+: { contact+: { name: name } } },

        withUrl(url): { info+: { contact+: { url: url } } },

        withEmail(email): { info+: { contact+: { email: email } } },

      },
    },

    externalDocs: {
      withDescription(description): { externalDocs+: { description: description } },

      withUrl(url): { externalDocs+: { url: url } },

    },
    withServers(servers): { servers: if std.isArray(v=servers) then servers else [servers] },
    withServersMixin(servers): { servers+: if std.isArray(v=servers) then servers else [servers] },

    withSecurity(security): { security: if std.isArray(v=security) then security else [security] },
    withSecurityMixin(security): { security+: if std.isArray(v=security) then security else [security] },

    withTags(tags): { tags: if std.isArray(v=tags) then tags else [tags] },
    withTagsMixin(tags): { tags+: if std.isArray(v=tags) then tags else [tags] },

    withPaths(paths): { paths: paths },
    paths: {
      pathItem: {
        post: {
          withTags(tags): { post+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { post+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { post+: { summary: summary } },

          withDescription(description): { post+: { description: description } },

          withParameters(parameters): { post+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { post+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { post+: { requestBody: requestBody } },

          withDeprecated(deprecated): { post+: { deprecated: deprecated } },

          withSecurity(security): { post+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { post+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { post+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { post+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { post+: { externalDocs+: { description: description } } },

            withUrl(url): { post+: { externalDocs+: { url: url } } },

          },
          withOperationId(operationId): { post+: { operationId: operationId } },

          withCallbacks(callbacks): { post+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { post+: { responses+: { default: default } } },


            response: {
              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

            },

            reference: {},
          },
        },

        delete: {
          withOperationId(operationId): { delete+: { operationId: operationId } },

          withCallbacks(callbacks): { delete+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { delete+: { responses+: { default: default } } },


            response: {
              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

            },

            reference: {},
          },
          withTags(tags): { delete+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { delete+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { delete+: { summary: summary } },

          withDescription(description): { delete+: { description: description } },

          withParameters(parameters): { delete+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { delete+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { delete+: { requestBody: requestBody } },

          withDeprecated(deprecated): { delete+: { deprecated: deprecated } },

          withSecurity(security): { delete+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { delete+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { delete+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { delete+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { delete+: { externalDocs+: { description: description } } },

            withUrl(url): { delete+: { externalDocs+: { url: url } } },

          },
        },

        head: {
          withRequestBody(requestBody): { head+: { requestBody: requestBody } },

          withDeprecated(deprecated): { head+: { deprecated: deprecated } },

          withSecurity(security): { head+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { head+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { head+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { head+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { head+: { externalDocs+: { description: description } } },

            withUrl(url): { head+: { externalDocs+: { url: url } } },

          },
          withOperationId(operationId): { head+: { operationId: operationId } },

          withCallbacks(callbacks): { head+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { head+: { responses+: { default: default } } },


            response: {
              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

            },

            reference: {},
          },
          withTags(tags): { head+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { head+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { head+: { summary: summary } },

          withDescription(description): { head+: { description: description } },

          withParameters(parameters): { head+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { head+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

        },

        put: {
          withTags(tags): { put+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { put+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { put+: { summary: summary } },

          withDescription(description): { put+: { description: description } },

          withParameters(parameters): { put+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { put+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { put+: { requestBody: requestBody } },

          withDeprecated(deprecated): { put+: { deprecated: deprecated } },

          withSecurity(security): { put+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { put+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { put+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { put+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { put+: { externalDocs+: { description: description } } },

            withUrl(url): { put+: { externalDocs+: { url: url } } },

          },
          withOperationId(operationId): { put+: { operationId: operationId } },

          withCallbacks(callbacks): { put+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { put+: { responses+: { default: default } } },


            response: {
              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

            },

            reference: {},
          },
        },
        withServers(servers): { servers: if std.isArray(v=servers) then servers else [servers] },
        withServersMixin(servers): { servers+: if std.isArray(v=servers) then servers else [servers] },


        get: {
          withOperationId(operationId): { get+: { operationId: operationId } },

          withCallbacks(callbacks): { get+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { get+: { responses+: { default: default } } },


            response: {
              withLinks(links): { links: links },

              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

            },

            reference: {},
          },
          withTags(tags): { get+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { get+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { get+: { summary: summary } },

          withDescription(description): { get+: { description: description } },

          withParameters(parameters): { get+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { get+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { get+: { requestBody: requestBody } },

          withDeprecated(deprecated): { get+: { deprecated: deprecated } },

          withSecurity(security): { get+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { get+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { get+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { get+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { get+: { externalDocs+: { description: description } } },

            withUrl(url): { get+: { externalDocs+: { url: url } } },

          },
        },

        options: {
          withTags(tags): { options+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { options+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { options+: { summary: summary } },

          withDescription(description): { options+: { description: description } },

          withParameters(parameters): { options+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { options+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { options+: { requestBody: requestBody } },

          withDeprecated(deprecated): { options+: { deprecated: deprecated } },

          withSecurity(security): { options+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { options+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { options+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { options+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { options+: { externalDocs+: { description: description } } },

            withUrl(url): { options+: { externalDocs+: { url: url } } },

          },
          withOperationId(operationId): { options+: { operationId: operationId } },

          withCallbacks(callbacks): { options+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { options+: { responses+: { default: default } } },


            response: {
              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

            },

            reference: {},
          },
        },

        patch: {
          withSummary(summary): { patch+: { summary: summary } },

          withDescription(description): { patch+: { description: description } },

          withParameters(parameters): { patch+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { patch+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { patch+: { requestBody: requestBody } },

          withDeprecated(deprecated): { patch+: { deprecated: deprecated } },

          withSecurity(security): { patch+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { patch+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { patch+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { patch+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { patch+: { externalDocs+: { description: description } } },

            withUrl(url): { patch+: { externalDocs+: { url: url } } },

          },
          withOperationId(operationId): { patch+: { operationId: operationId } },

          withCallbacks(callbacks): { patch+: { callbacks: callbacks } },


          responses: {
            withDefault(default): { patch+: { responses+: { default: default } } },


            response: {
              withDescription(description): { description: description },

              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

            },

            reference: {},
          },
          withTags(tags): { patch+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { patch+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

        },

        trace: {
          responses: {
            withDefault(default): { trace+: { responses+: { default: default } } },


            response: {
              withHeaders(headers): { headers: headers },

              withContent(content): { content: content },

              withLinks(links): { links: links },

              withDescription(description): { description: description },

            },

            reference: {},
          },
          withTags(tags): { trace+: { tags: if std.isArray(v=tags) then tags else [tags] } },
          withTagsMixin(tags): { trace+: { tags+: if std.isArray(v=tags) then tags else [tags] } },

          withSummary(summary): { trace+: { summary: summary } },

          withDescription(description): { trace+: { description: description } },

          withParameters(parameters): { trace+: { parameters: if std.isArray(v=parameters) then parameters else [parameters] } },
          withParametersMixin(parameters): { trace+: { parameters+: if std.isArray(v=parameters) then parameters else [parameters] } },

          withRequestBody(requestBody): { trace+: { requestBody: requestBody } },

          withDeprecated(deprecated): { trace+: { deprecated: deprecated } },

          withSecurity(security): { trace+: { security: if std.isArray(v=security) then security else [security] } },
          withSecurityMixin(security): { trace+: { security+: if std.isArray(v=security) then security else [security] } },

          withServers(servers): { trace+: { servers: if std.isArray(v=servers) then servers else [servers] } },
          withServersMixin(servers): { trace+: { servers+: if std.isArray(v=servers) then servers else [servers] } },


          externalDocs: {
            withDescription(description): { trace+: { externalDocs+: { description: description } } },

            withUrl(url): { trace+: { externalDocs+: { url: url } } },

          },
          withOperationId(operationId): { trace+: { operationId: operationId } },

          withCallbacks(callbacks): { trace+: { callbacks: callbacks } },

        },
        withParameters(parameters): { parameters: if std.isArray(v=parameters) then parameters else [parameters] },
        withParametersMixin(parameters): { parameters+: if std.isArray(v=parameters) then parameters else [parameters] },

        withRef(ref): { '$ref': ref },

        withSummary(summary): { summary: summary },

        withDescription(description): { description: description },

      },
    },

    components: {
      withLinks(links): { components+: { links: links } },
      links: {
        reference: {},

        link: {
          withParameters(parameters): { parameters: parameters },

          withRequestBody(requestBody): { requestBody: requestBody },

          withDescription(description): { description: description },


          server: {
            withUrl(url): { server+: { url: url } },

            withDescription(description): { server+: { description: description } },

            withVariables(variables): { server+: { variables: variables } },

          },
          withOperationId(operationId): { operationId: operationId },

          withOperationRef(operationRef): { operationRef: operationRef },

        },
      },
      withCallbacks(callbacks): { components+: { callbacks: callbacks } },
      callbacks: {
        reference: {},

        callback: {},
      },
      withResponses(responses): { components+: { responses: responses } },
      responses: {
        reference: {},

        response: {
          withDescription(description): { description: description },

          withHeaders(headers): { headers: headers },

          withContent(content): { content: content },

          withLinks(links): { links: links },

        },
      },
      withExamples(examples): { components+: { examples: examples } },
      examples: {
        reference: {},

        example: {},
      },
      withHeaders(headers): { components+: { headers: headers } },
      headers: {
        reference: {},

        header: {},
      },
      withSecuritySchemes(securitySchemes): { components+: { securitySchemes: securitySchemes } },
      securitySchemes: {
        reference: {},

        securityScheme: {},
      },
      withRequestBodies(requestBodies): { components+: { requestBodies: requestBodies } },
      requestBodies: {
        reference: {},

        requestBody: {
          withRequired(required): { required: required },

          withDescription(description): { description: description },

          withContent(content): { content: content },

        },
      },
      withSchemas(schemas): { components+: { schemas: schemas } },
      schemas: {
        schema: {},

        reference: {},
      },
      withParameters(parameters): { components+: { parameters: parameters } },
      parameters: {
        reference: {},

        parameter: {
          withExamples(examples): { examples: examples },

          withName(name): { name: name },

          withDescription(description): { description: description },

          withAllowEmptyValue(allowEmptyValue): { allowEmptyValue: allowEmptyValue },

          withExplode(explode): { explode: explode },

          withExample(example): { example: example },

          withIn(in_): { 'in': in_ },

          withStyle(style): { style: style },

          withRequired(required): { required: required },

          withSchema(schema): { schema: schema },

          withContent(content): { content: content },

          withDeprecated(deprecated): { deprecated: deprecated },

          withAllowReserved(allowReserved): { allowReserved: allowReserved },

        },
      },
    },
    withOpenapi(openapi): { openapi: openapi },

  },
}

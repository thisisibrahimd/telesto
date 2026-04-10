// imports
local openapi = import './openapi.jsonnet';
local o = openapi.openapi;


// helper functions
local ref(ref) = { '$ref': ref };
local schemaRef(name) = ref('#/components/schemas/' + name);
local responseRef(name) = ref('#/components/responses/' + name);
local parameterRef(name) = ref('#/components/parameters/' + name);
local jsonAndFormRequestBody(schemaName) = {
  required: true,
  content: {
    'application/json': {
      schema: schemaRef(schemaName),
    },
    'application/x-www-form-urlencoded': {
      schema: schemaRef(schemaName),
    },
  },
};
local withGetResponses(responses) = { get+: { responses+: responses } };
local withPutResponses(responses) = { put+: { responses+: responses } };
local withPostResponses(responses) = { post+: { responses+: responses } };
local withDeleteResponses(responses) = { delete+: { responses+: responses } };

// api objects
local errorSchema = {
  ErrorDetail: {
    additionalProperties: false,
    properties: {
      location: {
        description: "Where the error occurred, e.g. 'body.items[3].tags' or 'path.thing-id'",
        type: 'string',
      },
      message: {
        description: 'Error message text',
        type: 'string',
      },
      value: {
        description: 'The value at the given location',
      },
    },
    type: 'object',
  },
  Error: {
    additionalProperties: false,
    required: [
      'detail',
      'instance',
      'title',
      'type',
      'status',
    ],
    properties: {
      detail: {
        description: 'A human-readable explanation specific to this occurrence of the problem.',
        example: 'Property foo is required but is missing.',
        type: 'string',
      },
      errors: {
        description: 'Optional list of individual error details',
        items: {
          '$ref': '#/components/schemas/ErrorDetail',
        },
        nullable: true,
        type: 'array',
      },
      instance: {
        description: 'A URI reference that identifies the specific occurrence of the problem.',
        example: 'https://example.com/error-log/abc123',
        format: 'uri',
        type: 'string',
      },
      status: {
        description: 'HTTP status code',
        example: 400,
        format: 'int64',
        type: 'integer',
      },
      title: {
        description: 'A short, human-readable summary of the problem type. This value should not change between occurrences of the error.',
        example: 'Bad Request',
        type: 'string',
      },
      type: {
        default: 'about:blank',
        description: 'A URI reference to human-readable documentation for the error.',
        example: 'https://example.com/errors/example',
        format: 'uri',
        type: 'string',
      },
    },
    type: 'object',
  },

};
local otelcolSchema = {
  type: 'object',
  required: [
    'id',
    'name',
  ],
  properties: {
    id: {
      type: 'string',
      readOnly: true,
    },
    name: {
      type: 'string',
    },
  },
};


// API
o.withOpenapi('3.0.0')
+ o.info.withTitle('Telesto API')
+ o.info.withVersion('0.0.0')
+ o.components.withSecuritySchemes(securitySchemes={
  cookeAuth: {
    type: 'apiKey',
    'in': 'cookie',
    name: 'ory_kratos_session',
  },
})
+ o.withSecurity(security=[
  {
    cookieAuth: [],
  },
])
+ o.components.withSchemas(schemas={
  Otelcols: {
    type: 'array',
    nullable: true,
    items: schemaRef('Otelcol'),
  },
  Otelcol: otelcolSchema,
  OtelcolCreate: otelcolSchema { properties: std.objectRemoveKey(otelcolSchema.properties, 'id') },
  OtelcolUpdate: otelcolSchema { properties: std.objectRemoveKey(otelcolSchema.properties, 'id') },
  ErrorDetail: errorSchema.ErrorDetail,
  Error: errorSchema.Error,
})
+ o.components.withParameters(parameters={
  otelcolId: {
    'in': 'path',
    name: 'id',
    required: true,
    schema: {
      type: 'string',
    },
    description: 'otelcol id',
  },
})
+ o.components.withResponses(responses={
  Error: {
    description: 'Error',
    content: {
      'application/problem+json': {
        schema: schemaRef('Error'),
      },
    },
  },
})
+ o.withPaths(paths={
  '/api/v1/otelcols': {}
                      // // list otelcols
                      // + o.paths.pathItem.get.withOperationId('list-otelcol')
                      // + o.paths.pathItem.get.withDescription('list otelcols')
                      // + o.paths.pathItem.get.withTags(tags=['otelcol'])
                      // + withGetResponses(responses={
                      //   '200': {}
                      //          + o.paths.pathItem.get.responses.response.withDescription('a list of otelcols')
                      //          + o.paths.pathItem.get.responses.response.withContent(content={
                      //            'application/json': {
                      //              schema: schemaRef('Otelcols'),
                      //            },
                      //          }),
                      //   '204': {}
                      //          + o.paths.pathItem.get.responses.response.withDescription('no otelcols'),
                      // })


                      // create otelcol
                      + o.paths.pathItem.post.withOperationId('create-otelcol')
                      + o.paths.pathItem.post.withDescription('create a otelcol')
                      + o.paths.pathItem.post.withTags(tags=['otelcol'])
                      + o.paths.pathItem.post.withRequestBody(jsonAndFormRequestBody('OtelcolCreate'))
                      + o.paths.pathItem.post.responses.withDefault(default=responseRef('Error'))
                      + { post+: { responses+: { default+: { 'x-go-name': 'Error' } } } }
                      + withPostResponses(responses={
                        '201': {}
                               + o.paths.pathItem.post.responses.response.withDescription('created an otelcol')
                               + o.paths.pathItem.post.responses.response.withHeaders(headers={
                                 Location: {
                                   schema: {
                                     type: 'string',
                                   },
                                 },
                               }),
                      }),
  '/api/v1/otelcols/{id}': {}
                           + o.paths.pathItem.withParametersMixin(parameters=[
                             parameterRef('otelcolId'),
                           ])


                           // // get otelcol
                           // + o.paths.pathItem.get.withOperationId('get-otelcol')
                           // + o.paths.pathItem.get.withDescription('get a single otelcol')
                           // + o.paths.pathItem.get.withTags(tags=['otelcol'])
                           // + withGetResponses(responses={
                           //   '200': {}
                           //          + o.paths.pathItem.get.responses.response.withDescription('an otelcols')
                           //          + o.paths.pathItem.get.responses.response.withContent(content={
                           //            'application/json': {
                           //              schema: schemaRef('Otelcol'),
                           //            },
                           //          }),
                           //   '404': {}
                           //          + o.paths.pathItem.get.responses.response.withDescription('otelcol not found'),
                           // })


                           // update otelcol
                           + o.paths.pathItem.put.withOperationId('update-otelcol')
                           + o.paths.pathItem.put.withDescription('update a single otelcol')
                           + o.paths.pathItem.put.withTags(tags=['otelcol'])
                           + o.paths.pathItem.put.withRequestBody(jsonAndFormRequestBody('OtelcolUpdate'))
                           + o.paths.pathItem.put.responses.withDefault(default=responseRef('Error'))
                           + withPutResponses(responses={
                             '204': {}
                                    + o.paths.pathItem.put.responses.response.withDescription('updated otelcol')
                                    + o.paths.pathItem.put.responses.response.withHeaders(headers={
                                      Location: {
                                        schema: {
                                          type: 'string',
                                        },
                                      },
                                    }),
                           })


                           // delete otelcol
                           + o.paths.pathItem.delete.withOperationId('delete-otelcol')
                           + o.paths.pathItem.delete.withDescription('delete an otelcol')
                           + o.paths.pathItem.delete.withTags(tags=['otelcol'])
                           + o.paths.pathItem.delete.responses.withDefault(default=responseRef('Error'))
                           + withDeleteResponses(responses={
                             '204': {}
                                    + o.paths.pathItem.get.responses.response.withDescription('delete otelcol'),
                           }),
})

// ignore_for_file: avoid_dynamic_calls

import 'package:ion_openapi/ion_openapi.dart';
import 'package:ion_router/ion_router.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

void main() {
  group('OpenApi', () {
    test('extracts operations correctly', () {
      final router = Router();

      router.post(
        '/login',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'Login',
            parameters: [
              const .query(
                'include_details',
                description: 'Include user details',
              ),
            ],
            body: .json(.object()),
            responses: {
              .ok: .json(.object(), description: 'Success'),
              .unauthorized: .text(description: 'Failed'),
            },
          ),
        ],
      );

      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'Test API', version: '1.0.0'),
        servers: [
          const ApiServer(url: 'https://api.test.com/v1', description: 'Prod'),
        ],
        security: [.bearer()],
        tags: [
          const ApiTag(name: 'Auth', description: 'Authentication ops'),
        ],
        components: ApiComponents(
          securitySchemes: [.httpBearer()],
        ),
      );

      final json = builder.toJson() as dynamic;

      expect(json['openapi'], '3.2.0');
      expect(json['info']['title'], 'Test API');
      expect(json['servers'][0]['url'], 'https://api.test.com/v1');
      expect(json['security'][0]['bearerAuth'], isEmpty);
      expect(json['tags'][0]['name'], 'Auth');

      expect(
        json['components']['securitySchemes']['bearerAuth']['type'],
        'http',
      );
      expect(json['paths'], contains('/login'));

      final loginOp = json['paths']['/login']['post'];
      expect(loginOp['summary'], 'Login');

      final parameters = loginOp['parameters'];
      expect(parameters.length, 1);
      expect(parameters[0]['name'], 'include_details');
      expect(parameters[0]['in'], 'query');

      final schema =
          loginOp['requestBody']['content']['application/json']['schema'];
      expect(schema['type'], 'object');

      final responses = loginOp['responses'];
      expect(responses['200']['description'], 'Success');
      expect(responses['401']['description'], 'Failed');
    });

    test('extracts schemas with title', () {
      final router = Router();

      final userSchema = Schema.object(
        title: 'UserDto',
        properties: {'id': .string()},
      );

      router.get(
        '/users',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'Get Users',
            responses: {
              .ok: .json(.list(items: userSchema)),
            },
          ),
        ],
      );

      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'Test API', version: '1.0.0'),
      );

      final json = builder.toJson() as dynamic;

      // Check path ref
      final listSchema =
          json['paths']['/users']['get']['responses']['200']['content']['application/json']['schema'];
      expect(listSchema['type'], 'array');
      expect(listSchema['items'][r'$ref'], '#/components/schemas/UserDto');

      // Check components
      final userDto = json['components']['schemas']['UserDto'];
      expect(userDto['type'], 'object');
      expect(userDto['title'], 'UserDto');
    });

    test('handles SSE and headers correctly', () {
      final router = Router();

      router.get(
        '/events',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'SSE Events',
            responses: {
              .ok: .sse(
                .object(
                  properties: {'status': .string()},
                ),
                description: 'Event stream',
                headers: {
                  'X-Rate-Limit': ApiHeader(
                    description: 'Calls per hour allowed by the user',
                    schema: .integer(),
                  ),
                },
              ),
            },
          ),
        ],
      );

      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'Test API', version: '1.0.0'),
      );

      final json = builder.toJson() as dynamic;
      final okResponse = json['paths']['/events']['get']['responses']['200'];

      // Check SSE content
      final content = okResponse['content'];
      expect(content, contains('text/event-stream'));
      expect(content['text/event-stream']['itemSchema']['type'], 'object');

      // Check Headers
      final headers = okResponse['headers'];
      expect(headers, contains('X-Rate-Limit'));
      expect(
        headers['X-Rate-Limit']['description'],
        'Calls per hour allowed by the user',
      );
      expect(headers['X-Rate-Limit']['schema']['type'], 'integer');
    });

    test('handles webhooks and bumps version to 3.2.0', () {
      final router = Router();
      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'Test API', version: '1.0.0'),
        webhooks: {
          'onTaskCompleted': ApiWebhook(
            post: ApiOperation(
              summary: 'Task Completed',
              body: .json(
                .object(
                  title: 'WebhookPayload',
                  properties: {'taskId': .string()},
                ),
              ),
              responses: {
                .ok: const .empty(),
              },
            ),
          ),
        },
      );

      final json = builder.toJson() as dynamic;
      expect(json['openapi'], '3.2.0');

      expect(json['webhooks'], contains('onTaskCompleted'));
      final postOp = json['webhooks']['onTaskCompleted']['post'];
      expect(postOp['summary'], 'Task Completed');

      final schema =
          postOp['requestBody']['content']['application/json']['schema'];

      // Check if schema was extracted
      expect(schema[r'$ref'], '#/components/schemas/WebhookPayload');

      final webhookPayload = json['components']['schemas']['WebhookPayload'];
      expect(webhookPayload['type'], 'object');
    });

    test('handles externalDocs, servers and links correctly', () {
      final router = Router();
      router.post(
        '/users',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'Create User',
            operationId: 'createUser',
            servers: [
              const ApiServer(
                url: 'https://auth.test.com',
                description: 'Auth Server',
              ),
            ],
            externalDocs: const ApiExternalDocs(
              url: 'https://docs.test.com/create-user',
            ),
            responses: {
              .ok: .json(
                .object(),
                links: {
                  'GetUser': const ApiLink(
                    operationId: 'getUser',
                    parameters: {'id': r'$.body#/id'},
                    description: 'Get created user',
                  ),
                },
              ),
            },
          ),
        ],
      );

      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'Test API', version: '1.0.0'),
        externalDocs: const ApiExternalDocs(
          url: 'https://docs.test.com',
          description: 'Global docs',
        ),
        tags: [
          const ApiTag(
            name: 'Users',
            externalDocs: ApiExternalDocs(url: 'https://docs.test.com/users'),
          ),
        ],
      );

      final json = builder.toJson() as dynamic;

      // Global externalDocs
      expect(json['externalDocs']['url'], 'https://docs.test.com');
      expect(json['externalDocs']['description'], 'Global docs');

      // Tag externalDocs
      expect(
        json['tags'][0]['externalDocs']['url'],
        'https://docs.test.com/users',
      );

      // Operation externalDocs and servers
      final postOp = json['paths']['/users']['post'];

      expect(
        postOp['externalDocs']['url'],
        'https://docs.test.com/create-user',
      );
      expect(postOp['servers'][0]['url'], 'https://auth.test.com');

      // Links
      final links = postOp['responses']['200']['links'];
      expect(links, contains('GetUser'));
      expect(links['GetUser']['operationId'], 'getUser');
      expect(links['GetUser']['parameters']['id'], r'$.body#/id');
    });

    test('handles various media types', () {
      final router = Router();
      router.post(
        '/files',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'Upload and download files',
            body: .multipart(
              .object(properties: {'file': .string(format: 'binary')}),
            ),
            responses: {
              .ok: .binary(contentType: 'image/png'),
              .badRequest: .text(description: 'Error'),
            },
          ),
        ],
      );

      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'Test API', version: '1.0.0'),
      );
      final json = builder.toJson() as dynamic;
      final postOp = json['paths']['/files']['post'];

      // Check multipart request
      final reqContent = postOp['requestBody']['content'];
      expect(reqContent, contains('multipart/form-data'));
      expect(reqContent['multipart/form-data']['schema']['type'], 'object');

      final responses = postOp['responses'];

      // Check binary response
      final okContent = responses['200']['content'];
      expect(okContent, contains('image/png'));
      expect(okContent['image/png']['schema']['type'], 'string');
      expect(okContent['image/png']['schema']['format'], 'binary');

      // Check text response
      final badContent = responses['400']['content'];
      expect(badContent, contains('text/plain'));
      expect(badContent['text/plain']['schema']['type'], 'string');
    });

    test('handles all security requirement types', () {
      final req =
          ApiSecurityRequirement.oauth2(['read:users', 'write:users']) &
          ApiSecurityRequirement.apiKey() &
          ApiSecurityRequirement.basic() &
          ApiSecurityRequirement.custom('myAuth', ['scope']);

      const req2 = ApiSecurityRequirement({'anotherAuth': []});

      final router = Router();
      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'T', version: '1'),
        security: [req, req2],
      );

      final json = builder.toJson() as dynamic;
      expect(json['security'][0]['oauth2'], ['read:users', 'write:users']);
      expect(json['security'][0]['apiKey'], isEmpty);
      expect(json['security'][0]['basicAuth'], isEmpty);
      expect(json['security'][0]['myAuth'], ['scope']);
      expect(json['security'][1]['anotherAuth'], isEmpty);
    });

    test('handles server variables', () {
      final router = Router();
      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'T', version: '1'),
        servers: [
          const ApiServer(
            url: 'https://{env}.test.com:{port}',
            variables: {
              'env': ApiServerVariable(
                defaultValue: 'dev',
                enumValues: ['dev', 'prod'],
                description: 'Env',
              ),
              'port': ApiServerVariable(defaultValue: '443'),
            },
          ),
        ],
      );

      final json = builder.toJson() as dynamic;
      final vars = json['servers'][0]['variables'];
      expect(vars['env']['default'], 'dev');
      expect(vars['env']['enum'], ['dev', 'prod']);
      expect(vars['env']['description'], 'Env');
      expect(vars['port']['default'], '443');
      expect(vars['port']['enum'], isNull);
    });

    test('handles all parameter locations and request body constructors', () {
      final router = Router();
      router.post(
        '/all-params/{id}',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'All',
            parameters: [
              const .path('id', description: 'ID'),
              const .header('X-Req'),
              const .cookie('session'),
              const ApiParameter(name: 'custom', inLocation: .query),
            ],
            body: .form(.object()),
            responses: {
              .ok: .json(.object(), description: 'Ok'),
            },
          ),
        ],
      );

      router.post(
        '/raw',
        (req) => const .status(.ok),
        meta: [
          ApiOperation(
            summary: 'Raw',
            body: .binary(contentType: 'application/pdf'),
            responses: {},
          ),
        ],
      );

      final builder = OpenApi.fromRouter(
        router,
        info: const OpenApiInfo(title: 'T', version: '1'),
      );

      final json = builder.toJson() as dynamic;
      final params = json['paths']['/all-params/{id}']['post']['parameters'];
      expect(params[0]['in'], 'path');
      expect(params[1]['in'], 'header');
      expect(params[2]['in'], 'cookie');
      expect(params[3]['in'], 'query');

      final reqBody = json['paths']['/all-params/{id}']['post']['requestBody'];
      expect(reqBody['content'], contains('application/x-www-form-urlencoded'));

      final rawBody = json['paths']['/raw']['post']['requestBody'];
      expect(rawBody['content'], contains('application/pdf'));
    });
  });
}

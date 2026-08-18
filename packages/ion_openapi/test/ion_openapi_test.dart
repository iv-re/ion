// ignore_for_file: avoid_dynamic_calls

import 'package:checks/checks.dart';
import 'package:ion_openapi/ion_openapi.dart';
import 'package:ion_router/ion_router.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/scaffolding.dart';

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

      check(json['openapi']).equals('3.2.0');
      check(json['info']['title']).equals('Test API');
      check(json['servers'][0]['url']).equals('https://api.test.com/v1');
      check(json['security'][0]['bearerAuth'] as List).isEmpty();
      check(json['tags'][0]['name']).equals('Auth');

      check(
        json['components']['securitySchemes']['bearerAuth']['type'],
      ).equals('http');
      check(json['paths'] as Map).containsKey('/login');

      final loginOp = json['paths']['/login']['post'];
      check(loginOp['summary']).equals('Login');

      final parameters = loginOp['parameters'];
      check(parameters.length).equals(1);
      check(parameters[0]['name']).equals('include_details');
      check(parameters[0]['in']).equals('query');

      final schema =
          loginOp['requestBody']['content']['application/json']['schema'];
      check(schema['type']).equals('object');

      final responses = loginOp['responses'];
      check(responses['200']['description']).equals('Success');
      check(responses['401']['description']).equals('Failed');
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
      check(listSchema['type']).equals('array');
      check(
        listSchema['items'][r'$ref'],
      ).equals('#/components/schemas/UserDto');

      // Check components
      final userDto = json['components']['schemas']['UserDto'];
      check(userDto['type']).equals('object');
      check(userDto['title']).equals('UserDto');
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
      check(content as Map).containsKey('text/event-stream');
      check(
        content['text/event-stream']['itemSchema']['type'],
      ).equals('object');

      // Check Headers
      final headers = okResponse['headers'];
      check(headers as Map).containsKey('X-Rate-Limit');
      check(
        headers['X-Rate-Limit']['description'],
      ).equals('Calls per hour allowed by the user');
      check(headers['X-Rate-Limit']['schema']['type']).equals('integer');
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
      check(json['openapi']).equals('3.2.0');

      check(json['webhooks'] as Map).containsKey('onTaskCompleted');
      final postOp = json['webhooks']['onTaskCompleted']['post'];
      check(postOp['summary']).equals('Task Completed');

      final schema =
          postOp['requestBody']['content']['application/json']['schema'];

      // Check if schema was extracted
      check(schema[r'$ref']).equals('#/components/schemas/WebhookPayload');

      final webhookPayload = json['components']['schemas']['WebhookPayload'];
      check(webhookPayload['type']).equals('object');
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
      check(json['externalDocs']['url']).equals('https://docs.test.com');
      check(json['externalDocs']['description']).equals('Global docs');

      // Tag externalDocs
      check(
        json['tags'][0]['externalDocs']['url'],
      ).equals('https://docs.test.com/users');

      // Operation externalDocs and servers
      final postOp = json['paths']['/users']['post'];

      check(
        postOp['externalDocs']['url'],
      ).equals('https://docs.test.com/create-user');
      check(postOp['servers'][0]['url']).equals('https://auth.test.com');

      // Links
      final links = postOp['responses']['200']['links'];
      check(links as Map).containsKey('GetUser');
      check(links['GetUser']['operationId']).equals('getUser');
      check(links['GetUser']['parameters']['id']).equals(r'$.body#/id');
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
      check(reqContent as Map).containsKey('multipart/form-data');
      check(
        reqContent['multipart/form-data']['schema']['type'],
      ).equals('object');

      final responses = postOp['responses'];

      // Check binary response
      final okContent = responses['200']['content'];
      check(okContent as Map).containsKey('image/png');
      check(okContent['image/png']['schema']['type']).equals('string');
      check(okContent['image/png']['schema']['format']).equals('binary');

      // Check text response
      final badContent = responses['400']['content'];
      check(badContent as Map).containsKey('text/plain');
      check(badContent['text/plain']['schema']['type']).equals('string');
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
      check(
        json['security'][0]['oauth2'] as List,
      ).deepEquals(['read:users', 'write:users']);
      check(json['security'][0]['apiKey'] as List).isEmpty();
      check(json['security'][0]['basicAuth'] as List).isEmpty();
      check(json['security'][0]['myAuth'] as List).deepEquals(['scope']);
      check(json['security'][1]['anotherAuth'] as List).isEmpty();
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
      check(vars['env']['default']).equals('dev');
      check(vars['env']['enum'] as List).deepEquals(['dev', 'prod']);
      check(vars['env']['description']).equals('Env');
      check(vars['port']['default']).equals('443');
      check(vars['port']['enum']).isNull();
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
      check(params[0]['in']).equals('path');
      check(params[1]['in']).equals('header');
      check(params[2]['in']).equals('cookie');
      check(params[3]['in']).equals('query');

      final reqBody = json['paths']['/all-params/{id}']['post']['requestBody'];
      check(
        reqBody['content'] as Map,
      ).containsKey('application/x-www-form-urlencoded');

      final rawBody = json['paths']['/raw']['post']['requestBody'];
      check(rawBody['content'] as Map).containsKey('application/pdf');
    });
  });
}

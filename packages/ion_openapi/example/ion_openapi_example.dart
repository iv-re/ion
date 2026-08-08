import 'package:ion_extra/ion_extra.dart';
import 'package:ion_openapi/ion_openapi.dart';
import 'package:ion_router/ion_router.dart';
import 'package:ion_web/ion_web.dart';

class TaskDto implements ToJson {
  TaskDto(this.id, this.title, this.completed);

  TaskDto.fromJson(JsonObject json)
    : id = json.integer('id'),
      title = json.string('title'),
      completed = json.boolean('completed');

  static final Schema schema = JsonObject.schema(
    TaskDto.fromJson,
    title: 'Task',
  );

  final int id;
  final String title;
  final bool completed;

  @override
  Map<String, Object?> toJson() {
    return {'id': id, 'title': title, 'completed': completed};
  }
}

class CreateTaskDto {
  CreateTaskDto.fromJson(JsonObject json)
    : title = json.string('title', rules: [.length(min: 1)]);

  static final Schema schema = JsonObject.schema(
    CreateTaskDto.fromJson,
    title: 'CreateTask',
  );

  final String title;
}

void main() async {
  final app = Router();

  final tasks = <TaskDto>[];

  app.use(
    Middlewares.errorHandler(
      onError: (req, error, stackTrace) {
        if (error is ValidationErrors) {
          return Json(error, status: .badRequest);
        }
        return const .status(.internalServerError);
      },
    ),
  );

  app.get(
    '/tasks',
    (req) => JsonList(tasks),
    meta: [
      ApiOperation(
        summary: 'List tasks',
        description: 'Returns a list of all tasks',
        tags: ['Tasks'],
        responses: {
          .ok: .json(
            .list(items: TaskDto.schema),
            description: 'List of tasks',
          ),
        },
      ),
    ],
  );

  app.post(
    '/tasks',
    (req) async {
      final payload = await req.json(CreateTaskDto.fromJson);
      final task = TaskDto(tasks.length + 1, payload.title, false);
      tasks.add(task);
      return Json(task);
    },
    meta: [
      ApiOperation(
        summary: 'Create task',
        description: 'Creates a new task and returns it',
        tags: ['Tasks'],
        body: .json(CreateTaskDto.schema),
        responses: {
          .ok: .json(TaskDto.schema, description: 'Created task'),
        },
      ),
    ],
  );

  app.route('/docs', (docs) {
    // Optional: protect docs with HTTP Basic Auth
    // docs.use(Middlewares.basicAuth(credentials: {'admin': 'admin'}));

    // Serve interactive UI on http://localhost:8080/docs
    docs.get(
      '/',
      scalarUi(title: 'API Reference', specUrl: '/docs/openapi.json'),
    );

    // Serve OpenAPI JSON spec
    docs.get('/openapi.json', (_) {
      final openApi = OpenApi.fromRouter(
        app,
        info: const OpenApiInfo(
          title: 'Todo API',
          version: '1.0.0',
        ),
        servers: [
          const ApiServer(url: 'http://127.0.0.1:3000', description: 'local'),
        ],
      );
      return Json(openApi);
    });
  });

  final server = await IonServer.serve(
    app.call,
    address: .loopbackIPv4,
    port: 3000,
  );

  print('Server listening on http://${server.address.host}:${server.port}');
}

Handler scalarUi({required String title, required String specUrl}) {
  final html =
      '''
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$title</title>
</head>
<body>
  <div id="scalar"></div>
  <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  <script>
    Scalar.createApiReference('#scalar', {
      url: '$specUrl',
      agent: { disabled: true },
      mcp: { disabled: true },
      hideClientButton: true,
      showDeveloperTools: "never"
    });
  </script>
</body>
</html>
''';

  return (req) => .text(
    html,
    headers: [const .contentType('text/html')],
  );
}

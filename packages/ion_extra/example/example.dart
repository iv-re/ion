import 'package:ion_extra/ion_extra.dart';
import 'package:ion_web/ion_web.dart';

class LoginDto {
  LoginDto.fromJson(JsonObject json)
    : email = json.string('email', rules: [.email()]),
      password = json.string('password');

  static final Schema schema = JsonObject.schema(
    LoginDto.fromJson,
    title: 'LoginDto',
  );

  final String email;
  final String password;
}

class AccessTokenDto implements ToJson {
  AccessTokenDto({required this.accessToken});

  final String accessToken;

  @override
  Map<String, Object?> toJson() => {'access_token': accessToken};
}

Future<void> main() async {
  print('--- LoginDto Schema ---');
  print(LoginDto.schema);

  final server = await IonServer.serve(
    (req) async {
      try {
        final payload = await req.json(LoginDto.fromJson);
        if (payload.email != 'ion@example.com' || payload.password != 'ion') {
          return .text('invalid credentials', status: .unauthorized);
        }

        return Json(AccessTokenDto(accessToken: '90f1ae0b7ace00a7659775a0'));
      } on ValidationErrors catch (error) {
        return Json(error, status: .badRequest);
      }
    },
    address: .loopbackIPv4,
    port: 3000,
  );

  print('Server listening on http://${server.address.host}:${server.port}');
}

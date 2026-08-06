import 'package:json_annotation/json_annotation.dart';

part 'refresh_token_request_dto.g.dart';

@JsonSerializable(createFactory: false)
class RefreshTokenRequestDto {
  const RefreshTokenRequestDto({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => _$RefreshTokenRequestDtoToJson(this);
}

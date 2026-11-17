import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/reward_model.dart';

class RewardsApiService {
  RewardsApiService({ApiClient? client})
    : _client = client ?? ApiClient(),
      _ownsClient = client == null;
  final ApiClient _client;
  final bool _ownsClient;

  Future<List<RewardModel>> fetchRewards({
    String status = 'all',
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final data = await _client.get(
        ApiConstants.rewardsHistory,
        query: {'status': status, 'page': '$page', 'limit': '$limit'},
      );
      if (data is! Map || data['items'] is! List) {
        throw const RewardsApiException(
          'The server returned an invalid rewards list.',
        );
      }
      return (data['items'] as List)
          .whereType<Map>()
          .map((item) => RewardModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw RewardsApiException(error.message);
    }
  }

  Future<Map<String, dynamic>> fetchSummary() async {
    try {
      final data = await _client.get(ApiConstants.rewardsSummary);
      if (data is! Map) {
        throw const RewardsApiException(
          'The server returned an invalid rewards summary.',
        );
      }
      return Map<String, dynamic>.from(data);
    } on ApiException catch (error) {
      throw RewardsApiException(error.message);
    }
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}

class RewardsApiException implements Exception {
  const RewardsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

import '../models/reward_model.dart';
import '../services/rewards_api_service.dart';

class RewardsRepository {
  RewardsRepository({required this.apiService});

  final RewardsApiService apiService;

  Future<List<RewardModel>> getRewards() {
    return apiService.fetchRewards();
  }

  Future<Map<String, dynamic>> getSummary() {
    return apiService.fetchSummary();
  }

  void dispose() {
    apiService.dispose();
  }
}

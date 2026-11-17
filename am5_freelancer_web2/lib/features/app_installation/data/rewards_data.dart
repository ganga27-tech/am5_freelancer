/// View model populated only from the backend installation reward APIs.
class RewardInfo {
  final int milestone;
  final String cashReward;
  final String gift;
  final String cashbackVoucher;
  final String additionalNote;

  const RewardInfo({
    required this.milestone,
    this.cashReward = '',
    this.gift = '',
    this.cashbackVoucher = '',
    this.additionalNote = '',
  });
}

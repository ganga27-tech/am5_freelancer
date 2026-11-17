import 'package:flutter/material.dart';

class ReferralPointsCard extends StatelessWidget {
  const ReferralPointsCard({
    super.key,
    this.points,
    this.level,
    this.levelName,
    this.nextLevelName,
    this.nextLevelPoints,
    this.pointsToNextLevel,
    this.progressPercentage,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Values must come from the backend.
  /// Null means that real data is not available yet.
  final int? points;
  final int? level;
  final String? levelName;
  final String? nextLevelName;
  final int? nextLevelPoints;
  final int? pointsToNextLevel;
  final double? progressPercentage;

  final bool isLoading;
  final String? errorMessage;

  static const Color navy = Color(0xFF101D45);
  static const Color blue = Color(0xFF2449A5);
  static const Color gold = Color(0xFFFFD778);
  static const Color lightText = Color(0xFFE1E9FF);

  bool get hasValidData =>
      points != null &&
      points! >= 0 &&
      ((levelName?.trim().isNotEmpty ?? false) || level != null) &&
      (progressPercentage != null || nextLevelPoints != null);

  @override
  Widget build(BuildContext context) {
    final int currentPoints = points ?? 0;
    final int currentLevel = level ?? 0;
    final int targetPoints = nextLevelPoints ?? 0;

    final bool hasTarget = targetPoints > currentPoints;
    final double progress = hasValidData
        ? (progressPercentage != null
              ? (progressPercentage! / 100).clamp(0.0, 1.0).toDouble()
              : targetPoints <= 0
              ? 1.0
              : (currentPoints / targetPoints).clamp(0.0, 1.0).toDouble())
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navy, blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: gold, size: 25),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your Referral Rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (isLoading)
            _buildLoadingState()
          else if (errorMessage != null)
            _buildErrorState(errorMessage!)
          else if (!hasValidData)
            _buildEmptyState()
          else
            _buildRewardsContent(
              currentPoints: currentPoints,
              currentLevel: currentLevel,
              currentLevelName: levelName,
              nextLevelName: nextLevelName,
              targetPoints: targetPoints,
              hasTarget: hasTarget,
              pointsToNextLevel: pointsToNextLevel,
              progress: progress,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(gold),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Loading your referral rewards...',
              textAlign: TextAlign.center,
              style: TextStyle(color: lightText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: const Column(
        children: [
          Icon(Icons.stars_rounded, color: gold, size: 38),
          SizedBox(height: 12),
          Text(
            'Your rewards will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your referral points and progress will be '
            'displayed when your rewards data is available.',
            textAlign: TextAlign.center,
            style: TextStyle(color: lightText, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: gold, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: lightText,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsContent({
    required int currentPoints,
    required int currentLevel,
    required String? currentLevelName,
    required String? nextLevelName,
    required int targetPoints,
    required bool hasTarget,
    required int? pointsToNextLevel,
    required double progress,
  }) {
    final int remaining = pointsToNextLevel ??
        (hasTarget ? targetPoints - currentPoints : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, color: gold, size: 38),
            Text(
              '$currentPoints',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 35,
                fontWeight: FontWeight.w900,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                currentLevelName?.trim().isNotEmpty == true
                    ? currentLevelName!.trim()
                    : 'Level $currentLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(gold),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          nextLevelName?.trim().isNotEmpty == true
              ? '$remaining points to reach ${nextLevelName!.trim()}'
              : hasTarget
              ? '$remaining points to reach the next level'
              : 'Current reward target reached.',
          style: const TextStyle(color: lightText, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}

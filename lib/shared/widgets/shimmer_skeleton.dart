import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

/// A single shimmer-animated placeholder box.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmer,
      highlightColor: AppColors.surface2,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmer,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton loader for Khaata (transactions) tab — 5 card placeholders.
class KhaataSkeletonLoader extends StatelessWidget {
  const KhaataSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Balance summary skeleton
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Shimmer.fromColors(
                    baseColor: AppColors.shimmer,
                    highlightColor: AppColors.surface2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.shimmer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Shimmer.fromColors(
                    baseColor: AppColors.shimmer,
                    highlightColor: AppColors.surface2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.shimmer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Transaction card skeletons
        ...List.generate(5, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _SkeletonCard(),
          );
        }),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon placeholder
          const ShimmerBox(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 12),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 120, height: 14),
                SizedBox(height: 8),
                ShimmerBox(width: 80, height: 10),
              ],
            ),
          ),
          // Amount placeholder
          const ShimmerBox(width: 60, height: 18),
        ],
      ),
    );
  }
}

/// Skeleton loader for Tasks tab — 4 task placeholders.
class TaskSkeletonLoader extends StatelessWidget {
  const TaskSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips skeleton
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              ShimmerBox(width: 60, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerBox(width: 70, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerBox(width: 80, height: 32, borderRadius: 16),
            ],
          ),
        ),
        // Task card skeletons
        ...List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Checkbox placeholder
                  const ShimmerBox(width: 24, height: 24, borderRadius: 6),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(width: 150, height: 14),
                        SizedBox(height: 8),
                        ShimmerBox(width: 100, height: 10),
                      ],
                    ),
                  ),
                  // Priority badge
                  const ShimmerBox(width: 50, height: 22, borderRadius: 11),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

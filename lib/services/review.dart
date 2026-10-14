import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play review after positive moments (save written, progress
/// imported, bundle room finished): only after 3 such moments, at most once
/// every 60 days, never on launch or after an error.
class ReviewPrompt {
  static const _kCount = 'review_positive_count';
  static const _kLast = 'review_last_prompt';

  static Future<void> positiveMoment() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_kCount) ?? 0) + 1;
    await p.setInt(_kCount, n);
    final last = p.getInt(_kLast);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (n < 3) return;
    if (last != null && now - last < const Duration(days: 60).inMilliseconds) return;
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;
    await p.setInt(_kLast, now);
    await review.requestReview();
  }
}

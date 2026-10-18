import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _background = Color(0xFF111111);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);

class OnboardingStep {
  const OnboardingStep({
    required this.image,
    required this.title,
    required this.body,
    required this.points,
  });

  final String image;
  final String title;
  final String body;
  final List<String> points;
}

const onboardingSteps = [
  OnboardingStep(
    image: 'assets/onboarding/welcome.jpg',
    title: 'Welcome to zyvault',
    body: 'Your money, sorted by just talking. Spends, income, plans and goals in one calm place.',
    points: ['Every bank & cash', 'Made for ₹', 'Private'],
  ),
  OnboardingStep(
    image: 'assets/onboarding/talk.jpg',
    title: 'Just say it',
    body: 'Type or speak like you talk: "450 pizza last night", "35k salary on 6th". You see what it understood before it is saved.',
    points: ['Voice', 'Malayalam & Hinglish', 'Bill photos'],
  ),
  OnboardingStep(
    image: 'assets/onboarding/capture.jpg',
    title: 'Payments caught for you',
    body: 'Bank SMS and GPay, PhonePe or Paytm alerts become a quick question: where did this ₹500 go? Messages never leave your phone.',
    points: ['Bank SMS', 'UPI apps', 'Spam filter'],
  ),
  OnboardingStep(
    image: 'assets/onboarding/plans.jpg',
    title: 'Plans & reminders',
    body: 'Salary on the 1st, rent on the 5th, send ₹500 to Ravi at 6 pm. zyvault reminds you on time and records it for you.',
    points: ['Every month', 'Exact time', 'Notifications'],
  ),
  OnboardingStep(
    image: 'assets/onboarding/goals.jpg',
    title: 'Budgets & goals',
    body: 'Set a limit for each category, save for a Goa trip, and know who owes whom. You get a heads-up at 80%.',
    points: ['Budgets', 'Savings goals', 'Lend & borrow'],
  ),
  OnboardingStep(
    image: 'assets/onboarding/ask.jpg',
    title: 'Ask your money',
    body: '"How much on food this month?" "Who owes me?" Get the answer with a chart. Fingerprint lock keeps it yours.',
    points: ['Ask anything', 'Charts', 'Fingerprint lock'],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
    this.steps = onboardingSteps,
  });

  final VoidCallback onDone;
  final List<OnboardingStep> steps;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  var _page = 0;

  bool get _last => _page == widget.steps.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final step in widget.steps) {
      precacheImage(AssetImage(step.image), context);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_last) {
      widget.onDone();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.steps.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final position =
                    _pages.hasClients && _pages.position.haveDimensions
                    ? (_pages.page ?? 0) - index
                    : (_page - index).toDouble();
                return _StepView(
                  step: widget.steps[index],
                  offset: position.clamp(-1, 1).toDouble(),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _last ? 0 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: TextButton(
                    onPressed: _last ? null : widget.onDone,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(count: widget.steps.length, index: _page),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _last ? 'Get started' : 'Next',
                            key: ValueKey(_last),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step, required this.offset});

  final OnboardingStep step;

  /// -1..1 while swiping, 0 when this step is centred.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final fade = 1 - offset.abs();
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight * 0.42;
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageHeight,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(offset * 60, 0),
                  child: Transform.scale(
                    scale: 1.08 - 0.04 * fade,
                    child: Image.asset(
                      step.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: imageHeight * 0.55,
              left: 0,
              right: 0,
              height: imageHeight * 0.45 + 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00111111), _background],
                  ),
                ),
              ),
            ),
            Positioned(
              top: imageHeight - 40,
              left: 0,
              right: 0,
              bottom: 216 + MediaQuery.paddingOf(context).bottom,
              child: Opacity(
                opacity: fade.clamp(0, 1).toDouble(),
                child: Transform.translate(
                  offset: Offset(offset * -30, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: constraints.maxWidth - 48,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              textAlign: TextAlign.start,
                              maxLines: 3,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 60,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              step.body,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 18,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final point in step.points)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F1F1F),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFF2E2E2E),
                                      ),
                                    ),
                                    child: Text(
                                      point,
                                      style: const TextStyle(
                                        color: _lime,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: dot == index ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: dot == index ? _lime : const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
